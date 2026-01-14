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

    // Whisper requires 16kHz sample rate
    private let targetSampleRate: Double = 16000

    func startRecording() async throws {
        guard !isRecording else { return }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecorderError.engineInitFailed
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create target format for Whisper (16kHz, mono, float32)
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
        return normalizeAudio(samples)
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
