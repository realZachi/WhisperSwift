//
//  RecordingPillView.swift
//  whisperswift
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

    private let smoothingFactor: Float = 0.25
    private let peakDecay: Float = 0.92

    func update(level: Float) {
        currentLevel = level
        smoothedLevel += smoothingFactor * (level - smoothedLevel)

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
    case savedToClipboard(text: String)
}

// MARK: - Main View

struct RecordingPillView: View {
    var audioMonitor: AudioLevelMonitor
    var state: RecordingPillState

    @State private var isAnimating = false
    @Namespace private var pillNamespace

    var body: some View {
        pillContent
            .onAppear {
                isAnimating = true
            }
    }

    @ViewBuilder
    private var pillContent: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            liquidGlassContent
        } else {
            legacyGlassContent
        }
        #else
        legacyGlassContent
        #endif
    }

    // MARK: - Liquid Glass (macOS 26+)

    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    private var liquidGlassContent: some View {
        GlassEffectContainer {
            HStack(spacing: 14) {
                switch state {
                case .recording:
                    recordingIndicator
                case .processing:
                    processingIndicator
                case .savedToClipboard(let text):
                    SavedToClipboardIndicator(text: text)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: Capsule())
            .glassEffectID("pill", in: pillNamespace)
        }
        .animation(.smooth(duration: 0.4), value: state)
    }
    #endif

    // MARK: - Legacy Glass (macOS 13-25)

    private var legacyGlassContent: some View {
        ZStack {
            // Frosted glass background
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 20, y: 8)
                .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)

            // Content
            HStack(spacing: 14) {
                switch state {
                case .recording:
                    recordingIndicator
                case .processing:
                    processingIndicator
                case .savedToClipboard(let text):
                    SavedToClipboardIndicator(text: text)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .fixedSize()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state)
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 14) {
            RecordingDotView(isAnimating: isAnimating)

            WaveformView(
                level: CGFloat(audioMonitor.smoothedLevel),
                peak: CGFloat(audioMonitor.peakLevel)
            )
            .frame(width: 52, height: 26)
        }
    }

    // MARK: - Processing Indicator

    private var processingIndicator: some View {
        HStack(spacing: 10) {
            AppleSpinnerView()
                .frame(width: 20, height: 20)

            // Three animated dots
            ProcessingDotsView()
        }
    }
}

// MARK: - Saved to Clipboard Indicator

private struct SavedToClipboardIndicator: View {
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)

                Text("Saved to clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Text("Press ⌘⌃V to paste")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Recording Dot

private struct RecordingDotView: View {
    var isAnimating: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .fill(Color.red.opacity(0.25))
                .frame(width: 28, height: 28)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .opacity(isPulsing ? 0 : 0.5)

            // Main recording dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.35, blue: 0.35),
                            Color.red
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 14, height: 14)
                .shadow(color: Color.red.opacity(0.6), radius: 6)
        }
        .onAppear {
            guard isAnimating else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
        .onDisappear {
            isPulsing = false
        }
    }
}

// MARK: - Waveform Visualization

private struct WaveformView: View {
    var level: CGFloat
    var peak: CGFloat

    private let barCount = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    index: index,
                    level: level,
                    peak: peak,
                    totalBars: barCount
                )
            }
        }
        .animation(.interpolatingSpring(stiffness: 280, damping: 18), value: level)
    }
}

private struct WaveformBar: View {
    let index: Int
    let level: CGFloat
    let peak: CGFloat
    let totalBars: Int

    private var normalizedIndex: CGFloat {
        let center = CGFloat(totalBars - 1) / 2.0
        let distance = abs(CGFloat(index) - center)
        return 1.0 - (distance / center) * 0.5
    }

    private var barHeight: CGFloat {
        let minHeight: CGFloat = 5
        let maxHeight: CGFloat = 26
        let intensity = min(1.0, level * 1.3 + peak * 0.25)
        let height = minHeight + (maxHeight - minHeight) * intensity * normalizedIndex
        return max(minHeight, height)
    }

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.85),
                        Color.primary.opacity(0.45)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4, height: barHeight)
    }
}

// MARK: - Processing Dots Animation

private struct ProcessingDotsView: View {
    @State private var animatingDot = 0

    private let dotCount = 3

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(Color.primary.opacity(animatingDot == index ? 0.9 : 0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animatingDot == index ? 1.2 : 1.0)
            }
        }
        .task {
            await animateDots()
        }
    }

    private func animateDots() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.2)) {
                animatingDot = (animatingDot + 1) % dotCount
            }
        }
    }
}

// MARK: - Apple-style Spinner

private struct AppleSpinnerView: View {
    @State private var rotation: Double = 0

    private let segmentCount = 8

    var body: some View {
        ZStack {
            ForEach(0..<segmentCount, id: \.self) { index in
                SpinnerSegment(
                    index: index,
                    totalSegments: segmentCount
                )
            }
        }
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

private struct SpinnerSegment: View {
    let index: Int
    let totalSegments: Int

    private var opacity: Double {
        let step = 1.0 / Double(totalSegments)
        return step * Double(index + 1)
    }

    private var angle: Double {
        (360.0 / Double(totalSegments)) * Double(index)
    }

    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(opacity))
            .frame(width: 2.5, height: 6)
            .offset(y: -7)
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Preview

#Preview("Recording") {
    let monitor = AudioLevelMonitor()
    monitor.smoothedLevel = 0.5
    monitor.peakLevel = 0.7

    return ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        RecordingPillView(audioMonitor: monitor, state: .recording)
    }
    .frame(width: 400, height: 200)
}

#Preview("Processing") {
    let monitor = AudioLevelMonitor()

    return ZStack {
        LinearGradient(
            colors: [Color.orange.opacity(0.3), Color.pink.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        RecordingPillView(audioMonitor: monitor, state: .processing)
    }
    .frame(width: 400, height: 200)
}
