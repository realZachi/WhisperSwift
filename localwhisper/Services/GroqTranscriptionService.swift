//
//  GroqTranscriptionService.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Foundation

actor GroqTranscriptionService {
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
    private let apiKeyDefaultsKey = "groqApiKey"
    private let modelDefaultsKey = "groqModel"
    private let languageDefaultsKey = "groqLanguage"

    private let defaultModel = "whisper-large-v3-turbo"
    private let defaultLanguage = "de"

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
        let cleaned = cleanTranscription(decoded.text)
        await MainActor.run {
            logToFile("✅ Groq transcription received")
        }
        return cleaned
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

    private func cleanTranscription(_ text: String) -> String {
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
