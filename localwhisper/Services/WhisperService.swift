//
//  WhisperService.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Foundation
import WhisperKit

actor WhisperService {
    private let modelName = "large-v3-turbo"
    private let modelRepo = "argmaxinc/whisperkit-coreml"
    private let modelPathDefaultsKey = "whisperkitModelPath"
    private var pipe: WhisperKit?
    private var isDownloading = false

    init() async {
        await initialize()
    }

    func startModelDownloadIfNeeded() async {
        await downloadModelIfNeeded()
    }

    private func initialize() async {
        await updateStatus(phase: .idle, progress: nil, message: "Model not downloaded")
        if let existingPath = resolveExistingModelPath() {
            do {
                try await loadModel(from: existingPath)
                return
            } catch {
                await updateStatus(phase: .failed, progress: nil, message: "Model load failed: \(error.localizedDescription)")
                await log("❌ WhisperKit model load failed: \(error)")
            }
        }

        Task { [weak self] in
            await self?.downloadModelIfNeeded()
        }
    }

    private func candidateModelFolders() -> [URL] {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let storedPath = UserDefaults.standard.string(forKey: modelPathDefaultsKey) {
            candidates.append(URL(fileURLWithPath: storedPath))
        }

        if let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let appSupportRoot = appSupport.appendingPathComponent("LocalWhisper/WhisperKitModels", isDirectory: true)
            if !fileManager.fileExists(atPath: appSupportRoot.path) {
                try? fileManager.createDirectory(at: appSupportRoot, withIntermediateDirectories: true)
            }
            candidates.append(appSupportRoot.appendingPathComponent(modelName, isDirectory: true))
        }

        if let bundleURL = Bundle.main.resourceURL?
            .appendingPathComponent("WhisperKitModels", isDirectory: true)
            .appendingPathComponent(modelName, isDirectory: true) {
            candidates.append(bundleURL)
        }

        return candidates
    }

    private func resolveExistingModelPath() -> String? {
        let fileManager = FileManager.default
        let candidates = candidateModelFolders()

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate.path
        }

        return nil
    }

    private func loadModel(from path: String) async throws {
        let config = WhisperKitConfig(
            model: modelName,
            modelFolder: path,
            load: true,
            download: false
        )
        pipe = try await WhisperKit(config)
        UserDefaults.standard.set(path, forKey: modelPathDefaultsKey)
        await updateStatus(phase: .ready, progress: 1.0, message: "Model ready")
        await log("🤖 WhisperKit model loaded from: \(path)")
    }

    private func downloadModelIfNeeded() async {
        guard pipe == nil else { return }
        guard !isDownloading else { return }
        isDownloading = true

        await updateStatus(phase: .downloading, progress: 0, message: "Downloading model...")
        await log("⬇️ Downloading WhisperKit model \(modelName)...")

        do {
            let modelURL = try await WhisperKit.download(
                variant: modelName,
                from: modelRepo,
                progressCallback: { progress in
                    let fraction = progress.fractionCompleted
                    Task {
                        await self.updateDownloadProgress(fraction: fraction)
                    }
                }
            )
            UserDefaults.standard.set(modelURL.path, forKey: modelPathDefaultsKey)
            await log("⬇️ WhisperKit model downloaded to: \(modelURL.path)")
            try await loadModel(from: modelURL.path)
        } catch {
            await updateStatus(phase: .failed, progress: nil, message: "Download failed: \(error.localizedDescription)")
            await log("❌ WhisperKit model download failed: \(error)")
        }

        isDownloading = false
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let pipe = pipe else {
            throw WhisperError.modelNotReady
        }

        await log("🤖 Starting transcription with \(audioSamples.count) samples")

        // Check audio levels
        let maxAmplitude = audioSamples.map { abs($0) }.max() ?? 0
        let avgAmplitude = audioSamples.map { abs($0) }.reduce(0, +) / Float(audioSamples.count)
        await log("🔊 Audio levels - max: \(maxAmplitude), avg: \(avgAmplitude)")

        let options = DecodingOptions(
            task: .transcribe,
            language: "de",
            temperature: 0.0,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            wordTimestamps: false
        )

        let results = try await pipe.transcribe(audioArray: audioSamples, decodeOptions: options)
        let transcription = results.map { $0.text }.joined()
        await log("🤖 Raw transcription: '\(transcription)'")

        // Clean up the transcription
        let cleaned = cleanTranscription(transcription)
        await log("🤖 Cleaned transcription: '\(cleaned)'")
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
        guard pipe != nil else { return nil }
        return "WhisperKit \(modelName)"
    }

    private func updateDownloadProgress(fraction: Double) async {
        let percent = Int(fraction * 100)
        await updateStatus(phase: .downloading, progress: fraction, message: "Downloading model... \(percent)%")
    }

    private func updateStatus(phase: WhisperModelStatus.Phase, progress: Double?, message: String) async {
        await WhisperModelStatus.shared.update(
            phase: phase,
            progress: progress,
            message: message,
            modelName: modelName
        )
    }

    private func log(_ message: String) async {
        await MainActor.run {
            logToFile(message)
        }
    }
}

enum WhisperError: Error, LocalizedError {
    case modelNotReady

    var errorDescription: String? {
        switch self {
        case .modelNotReady:
            return "The WhisperKit model is still downloading or not available yet."
        }
    }
}
