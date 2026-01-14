//
//  WhisperService.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Foundation
import whisper

actor WhisperService {
    private var context: OpaquePointer?
    private let modelName = "ggml-base"

    init() async throws {
        try await loadModel()
    }

    deinit {
        if let context = context {
            whisper_free(context)
        }
    }

    private func loadModel() async throws {
        // Try to find model in bundle
        guard let modelPath = Bundle.main.path(forResource: modelName, ofType: "bin") else {
            // Try Resources/models folder
            let resourcesPath = Bundle.main.resourcePath ?? ""
            let modelsPath = (resourcesPath as NSString).appendingPathComponent("models/\(modelName).bin")

            if FileManager.default.fileExists(atPath: modelsPath) {
                try loadModelFromPath(modelsPath)
                return
            }

            throw WhisperError.modelNotFound
        }

        try loadModelFromPath(modelPath)
    }

    private func loadModelFromPath(_ path: String) throws {
        // Initialize whisper context with default parameters
        var params = whisper_context_default_params()
        params.use_gpu = true  // Enable Metal GPU acceleration

        context = whisper_init_from_file_with_params(path, params)

        guard context != nil else {
            throw WhisperError.modelLoadFailed
        }

        print("Whisper model loaded from: \(path)")
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let context = context else {
            throw WhisperError.notInitialized
        }

        logToFile("🤖 Starting transcription with \(audioSamples.count) samples")

        // Check audio levels
        let maxAmplitude = audioSamples.map { abs($0) }.max() ?? 0
        let avgAmplitude = audioSamples.map { abs($0) }.reduce(0, +) / Float(audioSamples.count)
        logToFile("🔊 Audio levels - max: \(maxAmplitude), avg: \(avgAmplitude)")

        // Configure whisper parameters for transcription
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)

        // Performance settings
        params.n_threads = Int32(min(4, ProcessInfo.processInfo.activeProcessorCount))

        // Output settings
        params.print_progress = false
        params.print_special = false
        params.print_realtime = false
        params.print_timestamps = false

        // Translate to English (set to false to keep original language)
        params.translate = false

        // Don't use single segment mode - let Whisper decide
        params.single_segment = false

        // Run transcription with language set to German
        logToFile("🤖 Running whisper_full with language: de")
        let langString = "de"
        let result = langString.withCString { langPtr in
            params.language = langPtr
            params.detect_language = false
            return audioSamples.withUnsafeBufferPointer { samplesPtr in
                whisper_full(context, params, samplesPtr.baseAddress, Int32(audioSamples.count))
            }
        }
        logToFile("🤖 whisper_full returned: \(result)")

        guard result == 0 else {
            throw WhisperError.transcriptionFailed
        }

        // Collect transcribed text from all segments
        let numSegments = whisper_full_n_segments(context)
        logToFile("🤖 Number of segments: \(numSegments)")
        var transcription = ""

        for i in 0..<numSegments {
            if let textPtr = whisper_full_get_segment_text(context, i) {
                let segmentText = String(cString: textPtr)
                logToFile("🤖 Segment \(i): '\(segmentText)'")
                transcription += segmentText
            }
        }

        logToFile("🤖 Raw transcription: '\(transcription)'")

        // Clean up the transcription
        let cleaned = cleanTranscription(transcription)
        logToFile("🤖 Cleaned transcription: '\(cleaned)'")
        return cleaned
    }

    private func cleanTranscription(_ text: String) -> String {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common whisper artifacts
        let artifacts = ["[BLANK_AUDIO]", "(blank audio)", "[MUSIC]", "[SILENCE]"]
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get information about the loaded model
    func getModelInfo() -> String? {
        guard context != nil else { return nil }
        return "Whisper Base (Multilingual)"
    }
}

enum WhisperError: Error, LocalizedError {
    case modelNotFound
    case modelLoadFailed
    case notInitialized
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Whisper model file not found. Please ensure ggml-base.bin is in the app bundle."
        case .modelLoadFailed:
            return "Failed to load the Whisper model."
        case .notInitialized:
            return "Whisper service is not initialized."
        case .transcriptionFailed:
            return "Transcription failed."
        }
    }
}
