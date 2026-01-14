//
//  AudioRecorder.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import AVFoundation
import Accelerate

actor AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private var isRecording = false

    // WhisperKit requires 16kHz sample rate
    private let targetSampleRate: Double = 16000

    // Callback for audio level updates (for waveform visualization)
    private var levelCallback: ((Float) -> Void)?

    func setLevelCallback(_ callback: @escaping (Float) -> Void) {
        self.levelCallback = callback
    }

    func startRecording() async throws {
        guard !isRecording else { return }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecorderError.engineInitFailed
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create target format for WhisperKit (16kHz, mono, float32)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatCreationFailed
        }

        // Create converter for sample rate conversion
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterCreationFailed
        }

        audioBuffer = []
        isRecording = true

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            Task {
                await self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
            }
        }

        // Prepare and start the audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        guard isRecording else { return }

        // Calculate output buffer capacity based on sample rate ratio
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputCapacity
        ) else { return }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if error == nil, let channelData = outputBuffer.floatChannelData?[0] {
            let frameCount = Int(outputBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            audioBuffer.append(contentsOf: samples)

            // Calculate RMS level for waveform visualization
            if let callback = levelCallback, frameCount > 0 {
                var rms: Float = 0
                vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
                // Scale RMS to 0-1 range (typical speech RMS is 0.01-0.3)
                let scaledLevel = min(rms * 5, 1.0)
                DispatchQueue.main.async {
                    callback(scaledLevel)
                }
            }
        }
    }

    func stopRecording() -> [Float] {
        isRecording = false

        if let audioEngine = audioEngine {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        let samples = audioBuffer
        audioBuffer = []

        logToFile("🎤 Raw samples: \(samples.count)")

        // Normalize audio if needed
        let normalized = normalizeAudio(samples)
        let trimmed = trimSilenceFromEnds(normalized)

        if !trimmed.isEmpty {
            let seconds = Double(trimmed.count) / targetSampleRate
            logToFile("🎤 Final samples: \(trimmed.count) (\(String(format: "%.2f", seconds))s)")
        } else {
            logToFile("🎤 Final samples: 0 (silence)")
        }

        return trimmed
    }

    private func normalizeAudio(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else {
            logToFile("🎤 Empty samples, returning as is")
            return samples
        }

        // Find max amplitude
        var maxAmplitude: Float = 0
        vDSP_maxmgv(samples, 1, &maxAmplitude, vDSP_Length(samples.count))

        logToFile("🎤 Max amplitude before normalization: \(maxAmplitude)")

        // If audio is very quiet or silent, return as is
        guard maxAmplitude > 0.001 else {
            logToFile("🎤 Audio too quiet (< 0.001), returning as is")
            return samples
        }

        // Normalize to 0.9 max amplitude
        let targetMax: Float = 0.9
        let scale = targetMax / maxAmplitude

        var normalizedSamples = [Float](repeating: 0, count: samples.count)
        var scaleVar = scale
        vDSP_vsmul(samples, 1, &scaleVar, &normalizedSamples, 1, vDSP_Length(samples.count))

        logToFile("🎤 Normalized with scale: \(scale)")
        return normalizedSamples
    }

    private func trimSilenceFromEnds(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }

        let sampleRate = Int(targetSampleRate)
        let frameLength = max(1, Int(Double(sampleRate) * 0.02)) // 20ms
        let hopLength = frameLength
        let paddingSamples = Int(Double(sampleRate) * 0.20) // 200ms

        if samples.count < frameLength {
            return samples
        }

        var rmsValues: [Float] = []
        rmsValues.reserveCapacity(samples.count / hopLength + 1)

        var maxRms: Float = 0
        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            var index = 0
            while index + frameLength <= buffer.count {
                var rms: Float = 0
                vDSP_rmsqv(base.advanced(by: index), 1, &rms, vDSP_Length(frameLength))
                rmsValues.append(rms)
                maxRms = max(maxRms, rms)
                index += hopLength
            }
        }

        guard !rmsValues.isEmpty else { return samples }

        // If overall energy is extremely low, treat as silence and skip transcription.
        if maxRms < 0.01 {
            logToFile("🎤 Detected mostly silent audio (max RMS: \(maxRms)); skipping transcription")
            return []
        }

        let threshold = max(0.01, maxRms * 0.10)

        var firstFrameIndex: Int?
        var lastFrameIndex: Int?
        for (index, rms) in rmsValues.enumerated() {
            if rms >= threshold {
                if firstFrameIndex == nil {
                    firstFrameIndex = index
                }
                lastFrameIndex = index
            }
        }

        guard let firstFrameIndex, let lastFrameIndex else {
            logToFile("🎤 No speech found above RMS threshold: \(threshold); skipping transcription")
            return []
        }

        let speechStartSample = firstFrameIndex * hopLength
        let speechEndSample = lastFrameIndex * hopLength + frameLength

        let trimmedStart = max(0, speechStartSample - paddingSamples)
        let trimmedEnd = min(samples.count, speechEndSample + paddingSamples)

        guard trimmedStart < trimmedEnd else { return [] }

        let trimmed = Array(samples[trimmedStart..<trimmedEnd])
        logToFile("🎤 Trimmed silence: \(samples.count) -> \(trimmed.count) samples (RMS threshold: \(threshold))")
        return trimmed
    }
}

enum AudioRecorderError: Error, LocalizedError {
    case engineInitFailed
    case formatCreationFailed
    case converterCreationFailed
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .engineInitFailed:
            return "Failed to initialize audio engine"
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .recordingFailed:
            return "Recording failed"
        }
    }
}
