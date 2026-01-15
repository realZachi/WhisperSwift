//
//  GroqTranscriptionService.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Foundation

actor GroqTranscriptionService {
    private let endpoint: URL
    private let cleanupEndpoint: URL
    private let apiKeyDefaultsKey = "groqApiKey"
    private let modelDefaultsKey = "groqModel"
    private let languageDefaultsKey = "groqLanguage"

    private let defaultModel = "whisper-large-v3-turbo"
    private let defaultLanguage = "de"
    private let cleanupModel = "moonshotai/kimi-k2-instruct-0905"

    private let cleanupSystemPrompt = #"""
You are a transcript editor. Your task is to convert raw speech transcriptions into clean, readable text while preserving the speaker's original meaning, language, and style.

## What to remove:
- False starts and self-corrections (keep only the final intended version)
- Filler words (um, uh, äh, euh, etto, etc.)
- Stutters and repetitions
- Verbal backtracking ("no wait", "I mean", "actually no", "sorry")
- Abandoned sentence fragments that were restarted

## What to preserve absolutely:
- The original language of the transcript
- The speaker's exact vocabulary and word choices
- Original spelling, capitalization, and formatting of terms
- Sentence structure — do not split or merge sentences
- Tone and register (formal/informal, mixed languages, slang)
- All substantive content and meaning
- Code-switching and technical terms exactly as spoken

## Strict rules:
1. NEVER paraphrase, summarize, or rewrite
2. NEVER change words to synonyms or "better" alternatives
3. NEVER correct grammar, spelling, or capitalization choices
4. NEVER add words not spoken (no "I will", "the", etc.)
5. NEVER change perspective or restructure for "proper" writing
6. ONLY delete — never transform or replace

Your job is deletion, not editing. If the speaker said "fix das", output "fix das" — not "behebe das Problem".

## Output:
Return only the cleaned transcript. No commentary, no explanations, no quotation marks.
"""#

    init() {
        guard let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions"),
              let cleanupEndpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            preconditionFailure("Invalid Groq API endpoint URL.")
        }
        self.endpoint = endpoint
        self.cleanupEndpoint = cleanupEndpoint
    }

    func transcribe(recording: AudioRecording) async throws -> String {
        guard let apiKey = resolveApiKey(), !apiKey.isEmpty else {
            throw GroqTranscriptionError.missingApiKey
        }

        let model = resolveModel()
        let language = resolveLanguage()
        let wavData = makeWavData(samples: recording.samples, sampleRate: Int(recording.sampleRate))

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fields: [(String, String)] = {
            var items: [(String, String)] = [
                ("model", model),
                ("temperature", "0"),
                ("response_format", "verbose_json")
            ]
            if let language {
                items.append(("language", language))
            }
            return items
        }()

        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fields: fields,
            fileFieldName: "file",
            filename: "recording.wav",
            mimeType: "audio/wav",
            fileData: wavData
        )

        await MainActor.run {
            logToFile("🌐 Sending audio to Groq (model: \(model))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqTranscriptionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GroqTranscriptionError.requestFailed(statusCode: httpResponse.statusCode, body: body)
        }

        let decoded = try await MainActor.run {
            try JSONDecoder().decode(GroqTranscriptionResponse.self, from: data)
        }
        let cleaned = cleanTranscriptionArtifacts(decoded.text)
        await MainActor.run {
            logToFile("✅ Groq transcription received")
        }
        return cleaned
    }

    func cleanTranscription(_ transcript: String) async throws -> String {
        guard let apiKey = resolveApiKey(), !apiKey.isEmpty else {
            throw GroqTranscriptionError.missingApiKey
        }

        var request = URLRequest(url: cleanupEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let messages = [
            GroqChatMessage(role: "system", content: cleanupSystemPrompt),
            GroqChatMessage(role: "user", content: transcript)
        ]

        let payload = GroqChatCompletionRequest(
            messages: messages,
            model: cleanupModel,
            temperature: 0.6,
            maxCompletionTokens: 4096,
            topP: 1,
            stream: false,
            stop: nil
        )

        let body = try await MainActor.run {
            try JSONEncoder().encode(payload)
        }
        request.httpBody = body

        await MainActor.run {
            logToFile("🌐 Sending transcript to Groq cleanup (model: \(cleanupModel))")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqTranscriptionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GroqTranscriptionError.requestFailed(statusCode: httpResponse.statusCode, body: body)
        }

        let decoded = try await MainActor.run {
            try JSONDecoder().decode(GroqChatCompletionResponse.self, from: data)
        }
        guard let content = decoded.choices.first?.message.content else {
            throw GroqTranscriptionError.invalidResponse
        }

        await MainActor.run {
            logToFile("✅ Groq cleanup received")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveApiKey() -> String? {
        if let key = UserDefaults.standard.string(forKey: apiKeyDefaultsKey), !key.isEmpty {
            return key
        }
        return ProcessInfo.processInfo.environment["GROQ_API_KEY"]
    }

    private func resolveModel() -> String {
        let stored = UserDefaults.standard.string(forKey: modelDefaultsKey) ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultModel : trimmed
    }

    private func resolveLanguage() -> String? {
        guard let stored = UserDefaults.standard.string(forKey: languageDefaultsKey) else {
            return defaultLanguage
        }
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func makeMultipartBody(
        boundary: String,
        fields: [(String, String)],
        fileFieldName: String,
        filename: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var body = Data()

        for (name, value) in fields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        return body
    }

    private func makeWavData(samples: [Float], sampleRate: Int) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = Int(bitsPerSample / 8)
        let dataSize = UInt32(samples.count * bytesPerSample)
        let chunkSize = UInt32(36) + dataSize
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bytesPerSample)
        let blockAlign = channels * UInt16(bytesPerSample)

        var data = Data(capacity: 44 + Int(dataSize))
        data.appendString("RIFF")
        data.appendLittleEndian(chunkSize)
        data.appendString("WAVE")
        data.appendString("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(channels)
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.appendString("data")
        data.appendLittleEndian(dataSize)

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let scaled = Int16(clamped * Float(Int16.max))
            data.appendLittleEndian(scaled)
        }

        return data
    }

    private func cleanTranscriptionArtifacts(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let artifacts = ["[BLANK_AUDIO]", "(blank audio)", "[MUSIC]", "[SILENCE]"]
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum GroqTranscriptionError: Error, LocalizedError {
    case missingApiKey
    case requestFailed(statusCode: Int, body: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Groq API key is missing. Set it in Settings or via GROQ_API_KEY."
        case let .requestFailed(statusCode, body):
            if body.isEmpty {
                return "Groq request failed with status \(statusCode)."
            }
            return "Groq request failed with status \(statusCode): \(body)"
        case .invalidResponse:
            return "Groq returned an invalid response."
        }
    }
}

private struct GroqTranscriptionResponse: Decodable {
    let text: String
}

private struct GroqChatCompletionRequest: Encodable {
    let messages: [GroqChatMessage]
    let model: String
    let temperature: Double
    let maxCompletionTokens: Int
    let topP: Double
    let stream: Bool
    let stop: String?

    enum CodingKeys: String, CodingKey {
        case messages
        case model
        case temperature
        case maxCompletionTokens = "max_completion_tokens"
        case topP = "top_p"
        case stream
        case stop
    }
}

private struct GroqChatMessage: Codable {
    let role: String
    let content: String
}

private struct GroqChatCompletionResponse: Decodable {
    let choices: [GroqChatChoice]
}

private struct GroqChatChoice: Decodable {
    let message: GroqChatMessage
}

private extension Data {
    nonisolated mutating func appendString(_ value: String) {
        if let data = value.data(using: .utf8) {
            append(data)
        }
    }

    nonisolated mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { bytes in
            append(contentsOf: bytes.bindMemory(to: UInt8.self))
        }
    }
}
