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
    var peakLevel: Float = 0

    private let smoothingFactor: Float = 0.3
    private let peakDecay: Float = 0.95

    func update(level: Float) {
        currentLevel = level
        smoothedLevel = smoothedLevel + smoothingFactor * (level - smoothedLevel)

        if level > peakLevel {
            peakLevel = level
        } else {
            peakLevel *= peakDecay
        }
    }

    func reset() {
        currentLevel = 0
        smoothedLevel = 0
        peakLevel = 0
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
        .frame(width: 120, height: 120)
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
    @State private var pulseRingPhase: CGFloat = 0
    @State private var glowRotation: Double = 0

    private let baseCircleSize: CGFloat = 32
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
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                pulseRingPhase = 1
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                glowRotation = 360
            }
        }
    }

    // MARK: - Recording Circle

    private var recordingCircle: some View {
        let audioLevel = CGFloat(audioMonitor.smoothedLevel)
        let peakLevel = CGFloat(audioMonitor.peakLevel)

        // Dynamic scaling: base size + significant growth with audio
        let dynamicScale = 1.0 + audioLevel * 0.8 + peakLevel * 0.3
        let currentSize = baseCircleSize * dynamicScale

        // Glow intensity based on audio
        let glowIntensity = 0.4 + audioLevel * 0.6
        let glowRadius = 8 + audioLevel * 25

        return ZStack {
            // Expanding pulse rings (multiple layers)
            ForEach(0..<3, id: \.self) { index in
                let ringDelay = CGFloat(index) * 0.33
                let ringPhase = (pulseRingPhase + ringDelay).truncatingRemainder(dividingBy: 1.0)
                let ringScale = 1.0 + ringPhase * (1.5 + audioLevel * 1.0)
                let ringOpacity = (1.0 - ringPhase) * (0.3 + audioLevel * 0.4)

                Circle()
                    .stroke(Color.white.opacity(ringOpacity), lineWidth: 1.5 - ringPhase)
                    .frame(width: currentSize, height: currentSize)
                    .scaleEffect(ringScale)
            }

            // Ambient glow layer (rotating)
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.1 + audioLevel * 0.2),
                            Color.cyan.opacity(0.1 + audioLevel * 0.15),
                            Color.white.opacity(0.1 + audioLevel * 0.2),
                            Color.purple.opacity(0.1 + audioLevel * 0.15),
                            Color.white.opacity(0.1 + audioLevel * 0.2)
                        ],
                        center: .center
                    )
                )
                .frame(width: currentSize + 30, height: currentSize + 30)
                .blur(radius: 15)
                .rotationEffect(.degrees(glowRotation))

            // Outer soft glow
            Circle()
                .fill(Color.white.opacity(0.15 + audioLevel * 0.25))
                .frame(width: currentSize + 20, height: currentSize + 20)
                .blur(radius: 12)

            // Main orb with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.95),
                            Color(white: 0.9)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: currentSize / 2
                    )
                )
                .frame(width: currentSize, height: currentSize)
                .shadow(color: Color.white.opacity(glowIntensity), radius: glowRadius)
                .shadow(color: Color.white.opacity(glowIntensity * 0.5), radius: glowRadius * 1.5)

            // Inner bright core (intensifies with voice)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.8 + audioLevel * 0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: currentSize / 3
                    )
                )
                .frame(width: currentSize * 0.6, height: currentSize * 0.6)
                .blur(radius: 2)

            // Specular highlight (top-left shine)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: currentSize / 4
                    )
                )
                .frame(width: currentSize * 0.5, height: currentSize * 0.5)
                .offset(x: -currentSize * 0.15, y: -currentSize * 0.15)

            // Voice activity burst effect
            if audioLevel > 0.3 {
                ForEach(0..<6, id: \.self) { index in
                    let angle = Double(index) * 60.0
                    let burstDistance = 8 + audioLevel * 20
                    let xOffset = cos(angle * .pi / 180) * burstDistance
                    let yOffset = sin(angle * .pi / 180) * burstDistance

                    Circle()
                        .fill(Color.white.opacity(0.4 + audioLevel * 0.4))
                        .frame(width: 3 + audioLevel * 4, height: 3 + audioLevel * 4)
                        .blur(radius: 1)
                        .offset(x: xOffset, y: yOffset)
                }
            }
        }
        .animation(.easeOut(duration: 0.06), value: audioMonitor.smoothedLevel)
        .animation(.easeOut(duration: 0.1), value: audioMonitor.peakLevel)
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
                    .shadow(color: .white.opacity(0.5), radius: 4)
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
