//
//  MockAudioRecorder.swift
//  whisperswiftTests
//
//  Mock implementation of AudioRecorder for testing
//

import Foundation
@testable import whisperswift

actor MockAudioRecorder {
    var isRecording = false
    var mockSamples: [Float] = []
    var shouldFail: Bool = false
    var failureError: AudioRecorderError = .recordingFailed
    var startCallCount: Int = 0
    var stopCallCount: Int = 0
    var levelCallback: ((Float) -> Void)?

    private let targetSampleRate: Double = 16000

    func setLevelCallback(_ callback: @escaping (Float) -> Void) {
        levelCallback = callback
    }

    func startRecording() async throws {
        startCallCount += 1

        if shouldFail {
            throw failureError
        }

        guard !isRecording else { return }
        isRecording = true
        mockSamples = []
    }

    func stopRecording() -> AudioRecording {
        stopCallCount += 1
        isRecording = false

        let samples = mockSamples
        mockSamples = []

        return AudioRecording(samples: samples, sampleRate: targetSampleRate)
    }

    // MARK: - Test Helpers

    func addMockSamples(_ samples: [Float]) {
        mockSamples.append(contentsOf: samples)
    }

    func generateMockSpeech(durationSeconds: Double) {
        let sampleCount = Int(durationSeconds * targetSampleRate)
        mockSamples = (0..<sampleCount).map { index in
            // Generate a simple sine wave with some noise to simulate speech
            let t = Double(index) / targetSampleRate
            let frequency: Double = 440 // A4 note
            let amplitude: Float = 0.3
            let noise = Float.random(in: -0.1...0.1)
            return amplitude * Float(sin(2 * .pi * frequency * t)) + noise
        }
    }

    func generateSilence(durationSeconds: Double) {
        let sampleCount = Int(durationSeconds * targetSampleRate)
        mockSamples = [Float](repeating: 0, count: sampleCount)
    }

    func reset() {
        isRecording = false
        mockSamples = []
        shouldFail = false
        failureError = .recordingFailed
        startCallCount = 0
        stopCallCount = 0
        levelCallback = nil
    }

    func simulateLevelUpdate(_ level: Float) {
        levelCallback?(level)
    }
}

// MARK: - Test Audio Sample Generators

enum TestAudioGenerator {
    static func sineWave(frequency: Double, duration: Double, sampleRate: Double, amplitude: Float = 0.5) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        return (0..<sampleCount).map { index in
            let t = Double(index) / sampleRate
            return amplitude * Float(sin(2 * .pi * frequency * t))
        }
    }

    static func whiteNoise(duration: Double, sampleRate: Double, amplitude: Float = 0.1) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        return (0..<sampleCount).map { _ in
            Float.random(in: -amplitude...amplitude)
        }
    }

    static func silence(duration: Double, sampleRate: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        return [Float](repeating: 0, count: sampleCount)
    }

    static func speechLike(duration: Double, sampleRate: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        return (0..<sampleCount).map { index in
            let t = Double(index) / sampleRate
            // Mix multiple frequencies like speech harmonics
            let f1: Double = 200 // Fundamental
            let f2: Double = 400 // First harmonic
            let f3: Double = 600 // Second harmonic

            let signal = 0.3 * Float(sin(2 * .pi * f1 * t)) +
                        0.2 * Float(sin(2 * .pi * f2 * t)) +
                        0.1 * Float(sin(2 * .pi * f3 * t)) +
                        Float.random(in: -0.05...0.05)

            return signal
        }
    }

    static func speechWithPauses(
        speechDuration: Double,
        pauseDuration: Double,
        repetitions: Int,
        sampleRate: Double
    ) -> [Float] {
        var samples: [Float] = []

        for _ in 0..<repetitions {
            // Add speech segment
            samples.append(contentsOf: speechLike(duration: speechDuration, sampleRate: sampleRate))
            // Add pause
            samples.append(contentsOf: silence(duration: pauseDuration, sampleRate: sampleRate))
        }

        return samples
    }
}
