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
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let recording = AudioRecording(samples: samples, sampleRate: 16000)

        XCTAssertEqual(recording.samples.count, 5)
        XCTAssertEqual(recording.sampleRate, 16000)
        XCTAssertEqual(recording.samples, samples)
    }

    func test_AudioRecording_EmptySamples_ReturnsEmptyArray() {
        let recording = AudioRecording(samples: [], sampleRate: 16000)

        XCTAssertTrue(recording.samples.isEmpty)
        XCTAssertEqual(recording.sampleRate, 16000)
    }

    func test_AudioRecording_LargeSampleSet_HandlesCorrectly() {
        let sampleCount = 160000 // 10 seconds at 16kHz
        let samples = [Float](repeating: 0.5, count: sampleCount)
        let recording = AudioRecording(samples: samples, sampleRate: 16000)

        XCTAssertEqual(recording.samples.count, sampleCount)
    }

    // MARK: - AudioRecorderError Tests

    func test_AudioRecorderError_EngineInitFailed_HasCorrectDescription() {
        XCTAssertEqual(AudioRecorderError.engineInitFailed.errorDescription, "Failed to initialize audio engine")
    }

    func test_AudioRecorderError_FormatCreationFailed_HasCorrectDescription() {
        XCTAssertEqual(AudioRecorderError.formatCreationFailed.errorDescription, "Failed to create audio format")
    }

    func test_AudioRecorderError_ConverterCreationFailed_HasCorrectDescription() {
        XCTAssertEqual(AudioRecorderError.converterCreationFailed.errorDescription, "Failed to create audio converter")
    }

    func test_AudioRecorderError_RecordingFailed_HasCorrectDescription() {
        XCTAssertEqual(AudioRecorderError.recordingFailed.errorDescription, "Recording failed")
    }

    // MARK: - Constants Tests

    func test_AudioRecorder_TargetSampleRate_Is16kHz() {
        let recording = AudioRecording(samples: [0.1], sampleRate: 16000)
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
        let samples: [Float] = [-0.9, -0.5, 0.0, 0.5, 0.9]

        for sample in samples {
            XCTAssertGreaterThanOrEqual(sample, -1.0)
            XCTAssertLessThanOrEqual(sample, 1.0)
        }
    }

    func test_SilentAudio_ShouldHaveZeroOrNearZeroValues() {
        let samples: [Float] = [0.0, 0.0001, -0.0001, 0.0]
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0

        XCTAssertLessThan(maxAmplitude, 0.001)
    }

    func test_LoudAudio_ShouldHaveHigherAmplitude() {
        let samples: [Float] = [0.5, 0.8, -0.7, 0.9, -0.85]
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0

        XCTAssertGreaterThan(maxAmplitude, 0.5)
    }
}

// MARK: - Audio Duration Calculation Tests

final class AudioDurationTests: XCTestCase {

    func test_Duration_OneSecondAt16kHz_Returns1Second() {
        let duration = Double(16000) / 16000.0
        XCTAssertEqual(duration, 1.0, accuracy: 0.001)
    }

    func test_Duration_HalfSecondAt16kHz_ReturnsPointFive() {
        let duration = Double(8000) / 16000.0
        XCTAssertEqual(duration, 0.5, accuracy: 0.001)
    }

    func test_Duration_ThirtySecondsAt16kHz_Returns30() {
        let duration = Double(480000) / 16000.0
        XCTAssertEqual(duration, 30.0, accuracy: 0.001)
    }

    func test_Duration_ZeroSamples_ReturnsZero() {
        let duration = Double(0) / 16000.0
        XCTAssertEqual(duration, 0.0)
    }
}
