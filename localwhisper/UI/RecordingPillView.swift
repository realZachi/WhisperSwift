//
//  RecordingPillView.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import SwiftUI

// MARK: - Audio Level Monitor

@Observable
final class AudioLevelMonitor {
    var currentLevel: Float = 0
    var smoothedLevel: Float = 0

    private let smoothingFactor: Float = 0.25

    func update(level: Float) {
        currentLevel = level
        smoothedLevel = smoothedLevel + smoothingFactor * (level - smoothedLevel)
    }

    func reset() {
        currentLevel = 0
        smoothedLevel = 0
    }
}

// MARK: - Recording State

enum RecordingPillState: Equatable {
    case recording
    case processing
}

// MARK: - Main View

struct RecordingPillView: View {
    var audioMonitor: AudioLevelMonitor
    var state: RecordingPillState

    @State private var morphProgress: CGFloat = 0

    var body: some View {
        ZStack {
            MorphingIndicatorView(
                audioMonitor: audioMonitor,
                isProcessing: state == .processing,
                morphProgress: morphProgress
            )
        }
        .frame(width: 60, height: 50)
        .onChange(of: state) { _, newState in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                morphProgress = newState == .processing ? 1 : 0
            }
        }
    }
}

// MARK: - Morphing Indicator

struct MorphingIndicatorView: View {
    var audioMonitor: AudioLevelMonitor
    var isProcessing: Bool
    var morphProgress: CGFloat

    @State private var dotAnimationPhase: CGFloat = 0

    private let circleSize: CGFloat = 28
    private let dotSize: CGFloat = 6
    private let dotSpacing: CGFloat = 10

    var body: some View {
        ZStack {
            // Recording circle - fades and splits
            recordingCircle
                .opacity(1 - morphProgress)
                .scaleEffect(1 + morphProgress * 0.3)
                .blur(radius: morphProgress * 4)

            // Processing dots - emerge from center
            processingDots
                .opacity(morphProgress)
                .scaleEffect(0.5 + morphProgress * 0.5)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                dotAnimationPhase = 1
            }
        }
    }

    // MARK: - Recording Circle

    private var recordingCircle: some View {
        let audioLevel = CGFloat(audioMonitor.smoothedLevel)
        let breathScale = 1.0 + audioLevel * 0.15
        let pulseIntensity = 0.3 + audioLevel * 0.5

        return ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Color.white.opacity(0.2 + audioLevel * 0.3), lineWidth: 1)
                .frame(width: circleSize + 8, height: circleSize + 8)
                .scaleEffect(breathScale * 1.1)
                .blur(radius: 1)

            // Main circle with subtle inner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.8)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: circleSize / 2
                    )
                )
                .frame(width: circleSize, height: circleSize)
                .scaleEffect(breathScale)
                .shadow(color: Color.white.opacity(pulseIntensity), radius: 6 + audioLevel * 6)

            // Inner warmth on audio
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1, green: 0.4, blue: 0.3).opacity(audioLevel * 0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: circleSize / 2.5
                    )
                )
                .frame(width: circleSize - 4, height: circleSize - 4)
                .scaleEffect(breathScale)
        }
        .animation(.easeOut(duration: 0.08), value: audioMonitor.smoothedLevel)
    }

    // MARK: - Processing Dots

    private var processingDots: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<3, id: \.self) { index in
                let delay = Double(index) * 0.15
                let phase = (dotAnimationPhase + delay).truncatingRemainder(dividingBy: 1.0)
                let wave = sin(phase * .pi * 2) * 0.5 + 0.5

                Circle()
                    .fill(Color.white.opacity(0.7 + wave * 0.3))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(0.7 + wave * 0.3)
                    .offset(y: -wave * 3)
            }
        }
    }
}

// MARK: - Preview

#Preview("Recording") {
    let monitor = AudioLevelMonitor()
    monitor.smoothedLevel = 0.4

    return RecordingPillView(audioMonitor: monitor, state: .recording)
        .padding(40)
        .background(Color.black.opacity(0.9))
}

#Preview("Processing") {
    let monitor = AudioLevelMonitor()

    return RecordingPillView(audioMonitor: monitor, state: .processing)
        .padding(40)
        .background(Color.black.opacity(0.9))
}
