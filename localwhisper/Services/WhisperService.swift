//
//  WhisperService.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Foundation
import WhisperKit

actor WhisperService {
    private let modelName = "openai_whisper-large-v3_turbo"
    private let modelDisplayName = "large-v3-turbo"
    private let modelRepo = "argmaxinc/whisperkit-coreml"
    private let modelPathDefaultsKey = "whisperkitModelPath"
    private var pipe: WhisperKit?
    private var isDownloading = false
    private var downloadCompleted = false

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
        var candidates: [URL] = []

        if let storedPath = UserDefaults.standard.string(forKey: modelPathDefaultsKey) {
            candidates.append(URL(fileURLWithPath: storedPath))
        }

        if let appSupportModel = appSupportModelFolder() {
            candidates.append(appSupportModel)
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

        for candidate in candidates {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    return candidate.path
                }
                return candidate.deletingLastPathComponent().path
            }
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
        downloadCompleted = false

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
            downloadCompleted = true
            let persistedURL = try persistDownloadedModel(at: modelURL)
            UserDefaults.standard.set(persistedURL.path, forKey: modelPathDefaultsKey)
            await log("⬇️ WhisperKit model downloaded to: \(modelURL.path)")
            if persistedURL.path != modelURL.path {
                await log("📦 Copied WhisperKit model to app support: \(persistedURL.path)")
            }
            await updateStatus(phase: .downloading, progress: 1.0, message: "Download complete. Loading model...")
            try await loadModel(from: persistedURL.path)
        } catch {
            await updateStatus(phase: .failed, progress: nil, message: "Download failed: \(error.localizedDescription)")
            await log("❌ WhisperKit model download failed: \(error)")
        }

        isDownloading = false
        downloadCompleted = false
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
        guard isDownloading, !downloadCompleted else { return }
        let percent = Int(fraction * 100)
        await updateStatus(phase: .downloading, progress: fraction, message: "Downloading model... \(percent)%")
    }

    private func updateStatus(phase: WhisperModelStatus.Phase, progress: Double?, message: String) async {
        await WhisperModelStatus.shared.update(
            phase: phase,
            progress: progress,
            message: message,
            modelName: modelDisplayName
        )
    }

    private func log(_ message: String) async {
        await MainActor.run {
            logToFile(message)
        }
    }

    private func appSupportModelFolder() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        let appSupportRoot = appSupport.appendingPathComponent("LocalWhisper/WhisperKitModels", isDirectory: true)
        if !fileManager.fileExists(atPath: appSupportRoot.path) {
            try? fileManager.createDirectory(at: appSupportRoot, withIntermediateDirectories: true)
        }
        return appSupportRoot.appendingPathComponent(modelName, isDirectory: true)
    }

    private func persistDownloadedModel(at downloadedURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let sourceURL = normalizedModelFolder(from: downloadedURL)
        guard let destinationURL = appSupportModelFolder() else { return sourceURL }
        if sourceURL.path == destinationURL.path {
            return destinationURL
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func normalizedModelFolder(from url: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return url.deletingLastPathComponent()
        }
        return url
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
