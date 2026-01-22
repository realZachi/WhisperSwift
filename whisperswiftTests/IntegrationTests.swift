//
//  IntegrationTests.swift
//  whisperswiftTests
//
//  Integration tests for WhisperSwift workflows
//

import XCTest
@testable import whisperswift

final class IntegrationTests: XCTestCase {

    // MARK: - Recording Workflow Tests

    func test_RecordingWorkflow_CreateRecording_ReturnsValidData() async {
        let mockRecorder = MockAudioRecorder()
        await mockRecorder.generateMockSpeech(durationSeconds: 1.0)

        do {
            try await mockRecorder.startRecording()
            let recording = await mockRecorder.stopRecording()
            XCTAssertFalse(recording.samples.isEmpty)
            XCTAssertEqual(recording.sampleRate, 16000)
        } catch {
            XCTFail("Recording should not fail: \(error)")
        }
    }

    func test_RecordingWorkflow_StartAndStop_TracksCorrectly() async {
        let mockRecorder = MockAudioRecorder()

        do {
            try await mockRecorder.startRecording()
            let isRecording = await mockRecorder.isRecording
            XCTAssertTrue(isRecording)

            _ = await mockRecorder.stopRecording()
            let isRecordingAfterStop = await mockRecorder.isRecording
            XCTAssertFalse(isRecordingAfterStop)
        } catch {
            XCTFail("Recording should not fail: \(error)")
        }
    }

    func test_RecordingWorkflow_MultipleRecordings_TracksCalls() async {
        let mockRecorder = MockAudioRecorder()

        do {
            try await mockRecorder.startRecording()
            _ = await mockRecorder.stopRecording()
            try await mockRecorder.startRecording()
            _ = await mockRecorder.stopRecording()

            let startCount = await mockRecorder.startCallCount
            let stopCount = await mockRecorder.stopCallCount
            XCTAssertEqual(startCount, 2)
            XCTAssertEqual(stopCount, 2)
        } catch {
            XCTFail("Recording should not fail: \(error)")
        }
    }

    // MARK: - Transcription Workflow Tests

    func test_TranscriptionWorkflow_MockService_ReturnsText() async {
        let mockService = MockGroqService()
        await mockService.reset()

        let recording = AudioRecording(samples: [0.1, 0.2, 0.3], sampleRate: 16000)
        do {
            let result = try await mockService.transcribe(recording: recording)
            XCTAssertFalse(result.isEmpty)
        } catch {
            XCTFail("Transcription should not fail: \(error)")
        }
    }

    func test_TranscriptionWorkflow_FailedRequest_ThrowsError() async {
        let mockService = MockGroqService()
        await mockService.reset()

        let recording = AudioRecording(samples: [0.1], sampleRate: 16000)
        do {
            _ = try await mockService.transcribe(recording: recording)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(true)
        }
    }

    // MARK: - Permission Workflow Tests

    func test_PermissionWorkflow_AllGranted_AllowsRecording() {
        let mockPermissions = MockPermissionManager()
        PermissionTestScenario.allGranted.configure(mockPermissions)
        XCTAssertTrue(mockPermissions.hasMicrophoneAccess)
        XCTAssertTrue(mockPermissions.hasAccessibilityAccess)
    }

    func test_PermissionWorkflow_MicrophoneDenied_BlocksRecording() {
        let mockPermissions = MockPermissionManager()
        PermissionTestScenario.microphoneDenied.configure(mockPermissions)
        XCTAssertFalse(mockPermissions.hasMicrophoneAccess)
        XCTAssertTrue(mockPermissions.hasAccessibilityAccess)
    }

    func test_PermissionWorkflow_AccessibilityDenied_LimitsFeatures() {
        let mockPermissions = MockPermissionManager()
        PermissionTestScenario.accessibilityDenied.configure(mockPermissions)
        XCTAssertTrue(mockPermissions.hasMicrophoneAccess)
        XCTAssertFalse(mockPermissions.hasAccessibilityAccess)
    }

    // MARK: - Audio Generation Tests

    func test_TestAudioGenerator_SineWave_GeneratesCorrectLength() {
        let samples = TestAudioGenerator.sineWave(frequency: 440, duration: 1.0, sampleRate: 16000)
        XCTAssertEqual(samples.count, 16000)
    }

    func test_TestAudioGenerator_Silence_GeneratesZeros() {
        let samples = TestAudioGenerator.silence(duration: 0.1, sampleRate: 16000)
        XCTAssertEqual(samples.count, 1600)
        XCTAssertTrue(samples.allSatisfy { $0 == 0 })
    }

    func test_TestAudioGenerator_WhiteNoise_HasVariation() {
        let samples = TestAudioGenerator.whiteNoise(duration: 0.1, sampleRate: 16000)
        XCTAssertEqual(samples.count, 1600)
        XCTAssertGreaterThan(Set(samples).count, 1)
    }

    func test_TestAudioGenerator_SpeechLike_HasCorrectAmplitudeRange() {
        let samples = TestAudioGenerator.speechLike(duration: 0.1, sampleRate: 16000)
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        XCTAssertLessThanOrEqual(maxAmplitude, 1.0)
    }

    // MARK: - End-to-End Simulation Tests

    func test_EndToEnd_RecordAndTranscribe_Simulation() async {
        let mockRecorder = MockAudioRecorder()
        let mockService = MockGroqService()

        await mockRecorder.generateMockSpeech(durationSeconds: 2.0)

        do {
            try await mockRecorder.startRecording()
            let recording = await mockRecorder.stopRecording()
            XCTAssertFalse(recording.samples.isEmpty)

            let transcription = try await mockService.transcribe(recording: recording)
            XCTAssertFalse(transcription.isEmpty)
        } catch {
            XCTFail("End-to-end simulation failed: \(error)")
        }
    }

    // MARK: - Performance Tests

    func test_EndToEnd_RecordingPerformance() async {
        let mockRecorder = MockAudioRecorder()
        await mockRecorder.generateMockSpeech(durationSeconds: 5.0)

        measure {
            let expectation = XCTestExpectation(description: "Recording")

            Task {
                do {
                    try await mockRecorder.startRecording()
                    _ = await mockRecorder.stopRecording()
                } catch {
                    // Ignore errors in performance test
                }
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - Mock Service Integration Tests

final class MockServiceIntegrationTests: XCTestCase {

    func test_MockGroqResponse_TranscriptionResponse_GeneratesValidJSON() {
        let response = MockGroqTranscriptionResponse(text: "Hello world", language: "en", duration: 1.5)
        let json = response.toJSON()

        XCTAssertEqual(json["text"] as? String, "Hello world")
        XCTAssertEqual(json["language"] as? String, "en")
        XCTAssertEqual(json["duration"] as? Double, 1.5)
    }

    func test_MockGroqResponse_TranscriptionResponse_GeneratesValidData() {
        let response = MockGroqTranscriptionResponse(text: "Test")
        XCTAssertNotNil(response.toData())
    }

    func test_MockGroqResponse_ChatResponse_GeneratesValidJSON() {
        let response = MockGroqChatResponse(cleanedText: "Cleaned text")
        XCTAssertNotNil(response.toJSON()["choices"])
    }

    func test_MockURLSession_SuccessResponse_ReturnsData() async {
        let session = MockURLSession()
        session.setSuccessResponse(json: ["text": "Test"], statusCode: 200)
        let request = URLRequest(url: URL(string: "https://api.groq.com/test")!)

        do {
            let (data, response) = try await session.data(for: request)
            XCTAssertNotNil(data)
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200)
            }
        } catch {
            XCTFail("Should not throw: \(error)")
        }
    }

    func test_MockURLSession_ErrorResponse_ReturnsErrorCode() async {
        let session = MockURLSession()
        session.setErrorResponse(statusCode: 401, body: "Unauthorized")
        let request = URLRequest(url: URL(string: "https://api.groq.com/test")!)

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 401)
            }
        } catch {
            XCTFail("Should not throw for error response: \(error)")
        }
    }
}
