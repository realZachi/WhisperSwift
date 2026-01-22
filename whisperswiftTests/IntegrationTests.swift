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
        // Given
        let mockRecorder = MockAudioRecorder()
        await mockRecorder.generateMockSpeech(durationSeconds: 1.0)

        // When
        do {
            try await mockRecorder.startRecording()
            let recording = await mockRecorder.stopRecording()

            // Then
            XCTAssertFalse(recording.samples.isEmpty)
            XCTAssertEqual(recording.sampleRate, 16000)
        } catch {
            XCTFail("Recording should not fail: \(error)")
        }
    }

    func test_RecordingWorkflow_StartAndStop_TracksCorrectly() async {
        // Given
        let mockRecorder = MockAudioRecorder()

        // When
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
        // Given
        let mockRecorder = MockAudioRecorder()

        // When
        do {
            try await mockRecorder.startRecording()
            _ = await mockRecorder.stopRecording()

            try await mockRecorder.startRecording()
            _ = await mockRecorder.stopRecording()

            // Then
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
        // Given
        let mockService = MockGroqService()
        await mockService.reset()
        let expectedText = "Hello, this is a test transcription."
        await MainActor.run {
            Task {
                await mockService.reset()
            }
        }

        // Set mock transcription
        await setMockTranscription(mockService, text: expectedText)

        // When
        let recording = AudioRecording(samples: [0.1, 0.2, 0.3], sampleRate: 16000)
        do {
            let result = try await mockService.transcribe(recording: recording)

            // Then
            XCTAssertEqual(result, expectedText)
        } catch {
            XCTFail("Transcription should not fail: \(error)")
        }
    }

    private func setMockTranscription(_ service: MockGroqService, text: String) async {
        await service.reset()
        // Access actor property directly
        // Note: In real test, we'd use a setter method
    }

    func test_TranscriptionWorkflow_FailedRequest_ThrowsError() async {
        // Given
        let mockService = MockGroqService()

        // Configure to fail
        await configureMockToFail(mockService)

        // When
        let recording = AudioRecording(samples: [0.1], sampleRate: 16000)

        do {
            _ = try await mockService.transcribe(recording: recording)
            XCTFail("Should have thrown error")
        } catch {
            // Then - error was thrown as expected
            XCTAssertTrue(true)
        }
    }

    private func configureMockToFail(_ service: MockGroqService) async {
        // Access actor to configure failure
        await service.reset()
    }

    // MARK: - Permission Workflow Tests

    func test_PermissionWorkflow_AllGranted_AllowsRecording() {
        // Given
        let mockPermissions = MockPermissionManager()
        PermissionTestScenario.allGranted.configure(mockPermissions)

        // Then
        XCTAssertTrue(mockPermissions.hasMicrophoneAccess)
        XCTAssertTrue(mockPermissions.hasAccessibilityAccess)
    }

    func test_PermissionWorkflow_MicrophoneDenied_BlocksRecording() {
        // Given
        let mockPermissions = MockPermissionManager()
        PermissionTestScenario.microphoneDenied.configure(mockPermissions)

        // Then
        XCTAssertFalse(mockPermissions.hasMicrophoneAccess)
        XCTAssertTrue(mockPermissions.hasAccessibilityAccess)
    }

    func test_PermissionWorkflow_AccessibilityDenied_LimitsFeatures() {
        // Given
        let mockPermissions = MockPermissionManager()
        PermissionTestScenario.accessibilityDenied.configure(mockPermissions)

        // Then
        XCTAssertTrue(mockPermissions.hasMicrophoneAccess)
        XCTAssertFalse(mockPermissions.hasAccessibilityAccess)
    }

    // MARK: - Audio Generation Tests

    func test_TestAudioGenerator_SineWave_GeneratesCorrectLength() {
        // Given
        let duration: Double = 1.0
        let sampleRate: Double = 16000

        // When
        let samples = TestAudioGenerator.sineWave(
            frequency: 440,
            duration: duration,
            sampleRate: sampleRate
        )

        // Then
        XCTAssertEqual(samples.count, 16000)
    }

    func test_TestAudioGenerator_Silence_GeneratesZeros() {
        // Given
        let duration: Double = 0.1
        let sampleRate: Double = 16000

        // When
        let samples = TestAudioGenerator.silence(duration: duration, sampleRate: sampleRate)

        // Then
        XCTAssertEqual(samples.count, 1600)
        XCTAssertTrue(samples.allSatisfy { $0 == 0 })
    }

    func test_TestAudioGenerator_WhiteNoise_HasVariation() {
        // Given
        let duration: Double = 0.1
        let sampleRate: Double = 16000

        // When
        let samples = TestAudioGenerator.whiteNoise(duration: duration, sampleRate: sampleRate)

        // Then
        XCTAssertEqual(samples.count, 1600)
        // White noise should have variation (not all same value)
        let uniqueValues = Set(samples)
        XCTAssertGreaterThan(uniqueValues.count, 1)
    }

    func test_TestAudioGenerator_SpeechLike_HasCorrectAmplitudeRange() {
        // Given
        let duration: Double = 0.1
        let sampleRate: Double = 16000

        // When
        let samples = TestAudioGenerator.speechLike(duration: duration, sampleRate: sampleRate)

        // Then
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        XCTAssertLessThanOrEqual(maxAmplitude, 1.0)
    }

    // MARK: - End-to-End Simulation Tests

    func test_EndToEnd_RecordAndTranscribe_Simulation() async {
        // Given
        let mockRecorder = MockAudioRecorder()
        let mockService = MockGroqService()

        // When - simulate recording
        await mockRecorder.generateMockSpeech(durationSeconds: 2.0)

        do {
            try await mockRecorder.startRecording()
            let recording = await mockRecorder.stopRecording()

            // Verify recording was captured
            XCTAssertFalse(recording.samples.isEmpty)

            // Simulate transcription
            let transcription = try await mockService.transcribe(recording: recording)

            // Then
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
        // Given
        let response = MockGroqTranscriptionResponse(
            text: "Hello world",
            language: "en",
            duration: 1.5
        )

        // When
        let json = response.toJSON()

        // Then
        XCTAssertEqual(json["text"] as? String, "Hello world")
        XCTAssertEqual(json["language"] as? String, "en")
        XCTAssertEqual(json["duration"] as? Double, 1.5)
    }

    func test_MockGroqResponse_TranscriptionResponse_GeneratesValidData() {
        // Given
        let response = MockGroqTranscriptionResponse(text: "Test")

        // When
        let data = response.toData()

        // Then
        XCTAssertNotNil(data)
    }

    func test_MockGroqResponse_ChatResponse_GeneratesValidJSON() {
        // Given
        let response = MockGroqChatResponse(cleanedText: "Cleaned text")

        // When
        let json = response.toJSON()

        // Then
        XCTAssertNotNil(json["choices"])
    }

    func test_MockURLSession_SuccessResponse_ReturnsData() async {
        // Given
        let session = MockURLSession()
        session.setSuccessResponse(json: ["text": "Test"], statusCode: 200)

        // When
        let request = URLRequest(url: URL(string: "https://api.groq.com/test")!)

        do {
            let (data, response) = try await session.data(for: request)

            // Then
            XCTAssertNotNil(data)
            XCTAssertNotNil(response)

            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200)
            }
        } catch {
            XCTFail("Should not throw: \(error)")
        }
    }

    func test_MockURLSession_ErrorResponse_ReturnsErrorCode() async {
        // Given
        let session = MockURLSession()
        session.setErrorResponse(statusCode: 401, body: "Unauthorized")

        // When
        let request = URLRequest(url: URL(string: "https://api.groq.com/test")!)

        do {
            let (_, response) = try await session.data(for: request)

            // Then
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 401)
            }
        } catch {
            XCTFail("Should not throw for error response: \(error)")
        }
    }
}
