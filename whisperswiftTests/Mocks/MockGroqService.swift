//
//  MockGroqService.swift
//  whisperswiftTests
//
//  Mock implementation of Groq transcription service for testing
//

import Foundation
@testable import whisperswift

/// Mock Groq service for testing transcription workflows
actor MockGroqService {
    var mockTranscription: String = "Test transcription"
    var shouldFail: Bool = false
    var failureError: GroqTranscriptionError = .invalidResponse
    var transcribeCallCount: Int = 0
    var cleanupCallCount: Int = 0
    var lastRecording: AudioRecording?
    var lastCleanupText: String?
    var lastCleanupProfile: TextCleanupProfile?
    var apiKey: String?

    init(apiKey: String? = "test-api-key") {
        self.apiKey = apiKey
    }

    nonisolated func hasApiKey() -> Bool {
        return true // For testing, always return true unless configured otherwise
    }

    func transcribe(recording: AudioRecording) async throws -> String {
        transcribeCallCount += 1
        lastRecording = recording

        if shouldFail {
            throw failureError
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        return mockTranscription
    }

    func cleanTranscription(_ transcript: String, profile: TextCleanupProfile = .default) async throws -> String {
        cleanupCallCount += 1
        lastCleanupText = transcript
        lastCleanupProfile = profile

        if shouldFail {
            throw failureError
        }

        // Simulate cleanup by removing common disfluencies
        var cleaned = transcript
        let disfluencies = ["um", "uh", "like", "you know"]
        for disfluency in disfluencies {
            cleaned = cleaned.replacingOccurrences(of: " \(disfluency) ", with: " ", options: .caseInsensitive)
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reset() {
        mockTranscription = "Test transcription"
        shouldFail = false
        failureError = .invalidResponse
        transcribeCallCount = 0
        cleanupCallCount = 0
        lastRecording = nil
        lastCleanupText = nil
        lastCleanupProfile = nil
    }
}

// MARK: - Mock Groq Response Structures

struct MockGroqTranscriptionResponse {
    let text: String
    let language: String?
    let duration: Double?

    init(text: String, language: String? = nil, duration: Double? = nil) {
        self.text = text
        self.language = language
        self.duration = duration
    }

    func toJSON() -> [String: Any] {
        var json: [String: Any] = ["text": text]
        if let language = language {
            json["language"] = language
        }
        if let duration = duration {
            json["duration"] = duration
        }
        return json
    }

    func toData() -> Data? {
        try? JSONSerialization.data(withJSONObject: toJSON())
    }
}

struct MockGroqChatResponse {
    let cleanedText: String

    func toJSON() -> [String: Any] {
        return [
            "choices": [
                [
                    "message": [
                        "content": "{\"cleaned_text\":\"\(cleanedText)\"}"
                    ]
                ]
            ]
        ]
    }

    func toData() -> Data? {
        try? JSONSerialization.data(withJSONObject: toJSON())
    }
}

// MARK: - Mock URLSession for Network Testing

class MockURLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }

        let data = mockData ?? Data()
        let response = mockResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return (data, response)
    }

    func setSuccessResponse(json: [String: Any], statusCode: Int = 200) {
        mockData = try? JSONSerialization.data(withJSONObject: json)
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.groq.com/test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        mockError = nil
    }

    func setErrorResponse(statusCode: Int, body: String) {
        mockData = body.data(using: .utf8)
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.groq.com/test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        mockError = nil
    }

    func setNetworkError(_ error: Error) {
        mockData = nil
        mockResponse = nil
        mockError = error
    }
}
