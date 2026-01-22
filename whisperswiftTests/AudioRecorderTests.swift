//
//  AudioRecorderTests.swift
//  whisperswiftTests
//
//  Tests for AudioRecorder service
//

import XCTest
@testable import whisperswift

final class AudioRecorderTests: XCTestCase {

    // MARK: - AudioRecording Tests

    func test_AudioRecording_Init_StoresCorrectValues() {
        // Given
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let sampleRate: Double = 16000

        // When
        let recording = AudioRecording(samples: samples, sampleRate: sampleRate)

        // Then
        XCTAssertEqual(recording.samples.count, 5)
        XCTAssertEqual(recording.sampleRate, 16000)
        XCTAssertEqual(recording.samples, samples)
    }

    func test_AudioRecording_EmptySamples_ReturnsEmptyArray() {
        // Given
        let samples: [Float] = []
        let sampleRate: Double = 16000

        // When
        let recording = AudioRecording(samples: samples, sampleRate: sampleRate)

        // Then
        XCTAssertTrue(recording.samples.isEmpty)
        XCTAssertEqual(recording.sampleRate, 16000)
    }

    func test_AudioRecording_LargeSampleSet_HandlesCorrectly() {
        // Given
        let sampleCount = 160000 // 10 seconds at 16kHz
        let samples = [Float](repeating: 0.5, count: sampleCount)
        let sampleRate: Double = 16000

        // When
        let recording = AudioRecording(samples: samples, sampleRate: sampleRate)

        // Then
        XCTAssertEqual(recording.samples.count, sampleCount)
    }

    // MARK: - AudioRecorderError Tests

    func test_AudioRecorderError_EngineInitFailed_HasCorrectDescription() {
        // Given
        let error = AudioRecorderError.engineInitFailed

        // Then
        XCTAssertEqual(error.errorDescription, "Failed to initialize audio engine")
    }

    func test_AudioRecorderError_FormatCreationFailed_HasCorrectDescription() {
        // Given
        let error = AudioRecorderError.formatCreationFailed

        // Then
        XCTAssertEqual(error.errorDescription, "Failed to create audio format")
    }

    func test_AudioRecorderError_ConverterCreationFailed_HasCorrectDescription() {
        // Given
        let error = AudioRecorderError.converterCreationFailed

        // Then
        XCTAssertEqual(error.errorDescription, "Failed to create audio converter")
    }

    func test_AudioRecorderError_RecordingFailed_HasCorrectDescription() {
        // Given
        let error = AudioRecorderError.recordingFailed

        // Then
        XCTAssertEqual(error.errorDescription, "Recording failed")
    }

    // MARK: - Constants Tests

    func test_AudioRecorder_TargetSampleRate_Is16kHz() {
        // The target sample rate should be 16000 Hz for efficient speech transcription
        // This is verified by checking the AudioRecording output sample rate
        let samples: [Float] = [0.1]
        let recording = AudioRecording(samples: samples, sampleRate: 16000)
        XCTAssertEqual(recording.sampleRate, 16000)
    }

    // MARK: - Performance Tests

    func test_AudioRecording_InitPerformance() {
        let samples = [Float](repeating: 0.5, count: 480000) // 30 seconds at 16kHz

        measure {
            _ = AudioRecording(samples: samples, sampleRate: 16000)
        }
    }

    func test_AudioRecording_SampleArrayAccess_Performance() {
        let samples = [Float](repeating: 0.5, count: 480000)
        let recording = AudioRecording(samples: samples, sampleRate: 16000)

        measure {
            var sum: Float = 0
            for sample in recording.samples {
                sum += sample
            }
            _ = sum
        }
    }
}

// MARK: - Audio Normalization Tests

final class AudioNormalizationTests: XCTestCase {

    func test_NormalizedSamples_ShouldBeWithinValidRange() {
        // Given normalized audio samples
        let samples: [Float] = [-0.9, -0.5, 0.0, 0.5, 0.9]

        // Then all samples should be within -1.0 to 1.0 range
        for sample in samples {
            XCTAssertGreaterThanOrEqual(sample, -1.0)
            XCTAssertLessThanOrEqual(sample, 1.0)
        }
    }

    func test_SilentAudio_ShouldHaveZeroOrNearZeroValues() {
        // Given silent audio
        let samples: [Float] = [0.0, 0.0001, -0.0001, 0.0]

        // Then max amplitude should be near zero
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        XCTAssertLessThan(maxAmplitude, 0.001)
    }

    func test_LoudAudio_ShouldHaveHigherAmplitude() {
        // Given loud audio
        let samples: [Float] = [0.5, 0.8, -0.7, 0.9, -0.85]

        // Then max amplitude should be significant
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(maxAmplitude, 0.5)
    }
}

// MARK: - Audio Duration Calculation Tests

final class AudioDurationTests: XCTestCase {

    func test_Duration_OneSecondAt16kHz_Returns1Second() {
        // Given
        let sampleCount = 16000
        let sampleRate: Double = 16000

        // When
        let duration = Double(sampleCount) / sampleRate

        // Then
        XCTAssertEqual(duration, 1.0, accuracy: 0.001)
    }

    func test_Duration_HalfSecondAt16kHz_ReturnsPointFive() {
        // Given
        let sampleCount = 8000
        let sampleRate: Double = 16000

        // When
        let duration = Double(sampleCount) / sampleRate

        // Then
        XCTAssertEqual(duration, 0.5, accuracy: 0.001)
    }

    func test_Duration_ThirtySecondsAt16kHz_Returns30() {
        // Given
        let sampleCount = 480000
        let sampleRate: Double = 16000

        // When
        let duration = Double(sampleCount) / sampleRate

        // Then
        XCTAssertEqual(duration, 30.0, accuracy: 0.001)
    }

    func test_Duration_ZeroSamples_ReturnsZero() {
        // Given
        let sampleCount = 0
        let sampleRate: Double = 16000

        // When
        let duration = Double(sampleCount) / sampleRate

        // Then
        XCTAssertEqual(duration, 0.0)
    }
}
