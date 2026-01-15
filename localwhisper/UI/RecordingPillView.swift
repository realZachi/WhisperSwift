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

    @State private var processingRotation: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let level = clamped(CGFloat(audioMonitor.smoothedLevel))
            let peak = clamped(CGFloat(audioMonitor.peakLevel))
            let plateSize = size * 0.88

            ZStack {
                basePlate(size: plateSize, level: level)

                recordingContent(size: plateSize, level: level, peak: peak)
                    .opacity(1 - morphProgress)
                    .scaleEffect(1 - morphProgress * 0.05)

                processingContent(size: plateSize)
                    .opacity(morphProgress)
                    .scaleEffect(0.9 + morphProgress * 0.1)
            }
            .frame(width: size, height: size)
        }
        .onAppear {
            if isProcessing {
                startProcessingRotation()
            }
        }
        .onChange(of: isProcessing) { _, newValue in
            if newValue {
                startProcessingRotation()
            }
        }
        .animation(.easeOut(duration: 0.12), value: audioMonitor.smoothedLevel)
        .animation(.easeOut(duration: 0.18), value: audioMonitor.peakLevel)
    }

    private func basePlate(size: CGFloat, level: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.18),
                            Color(white: 0.12),
                            Color(white: 0.08)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            Circle()
                .stroke(Color.white.opacity(0.08 + level * 0.12), lineWidth: 1)
                .blur(radius: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.35), radius: 10, y: 6)
    }

    private func recordingContent(size: CGFloat, level: CGFloat, peak: CGFloat) -> some View {
        let ringSize = size * 0.86
        let haloSize = size * 0.94
        let ringWidth = 2 + level * 2
        let arcLength = 0.18 + level * 0.55

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.22 + level * 0.35),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: haloSize * 0.55
                    )
                )
                .frame(width: haloSize, height: haloSize)

            Circle()
                .trim(from: 0, to: arcLength)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.cyan.opacity(0.8),
                            Color.white.opacity(0.2)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)

            waveformBars(size: size, level: level, peak: peak)
        }
        .frame(width: size, height: size)
    }

    private func processingContent(size: CGFloat) -> some View {
        let ringSize = size * 0.56

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 2)

            Circle()
                .trim(from: 0, to: 0.22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.cyan.opacity(0.45)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(processingRotation))
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func waveformBars(size: CGFloat, level: CGFloat, peak: CGFloat) -> some View {
        let maxHeight = size * 0.32
        let minHeight = size * 0.12
        let weights: [CGFloat] = [0.35, 0.6, 0.95, 0.6, 0.35]
        let intensity = clamped(level * 0.9 + peak * 0.25)

        return HStack(spacing: size * 0.05) {
            ForEach(0..<weights.count, id: \.self) { index in
                let weight = weights[index]
                let height = minHeight + (maxHeight - minHeight) * clamped(intensity * weight + 0.08)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.045, height: height)
                    .shadow(color: Color.white.opacity(0.15 + level * 0.25), radius: 2, y: 1)
            }
        }
    }

    private func startProcessingRotation() {
        processingRotation = 0
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            processingRotation = 360
        }
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
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
