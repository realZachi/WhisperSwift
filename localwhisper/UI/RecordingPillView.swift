//
//  RecordingPillView.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import SwiftUI

/// Observable object to receive audio levels from AudioRecorder
@Observable
final class AudioLevelMonitor {
    var levels: [Float] = Array(repeating: 0, count: 30)

    func update(level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    func reset() {
        levels = Array(repeating: 0, count: 30)
    }
}

struct RecordingPillView: View {
    var audioMonitor: AudioLevelMonitor
    @State private var isAnimating = false

    private let pillWidth: CGFloat = 200
    private let pillHeight: CGFloat = 44
    private let barCount = 30

    var body: some View {
        HStack(spacing: 3) {
            // Recording indicator dot
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(isAnimating ? 1.0 : 0.4)
                .animation(
                    Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // Waveform bars
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(level: audioMonitor.levels[index])
                }
            }
            .frame(height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            isAnimating = true
        }
    }
}

struct WaveformBar: View {
    let level: Float

    private var normalizedHeight: CGFloat {
        // Clamp level between 0 and 1, then scale for visual effect
        let clamped = min(max(CGFloat(level), 0), 1)
        // Minimum height of 0.1 so bars are always visible
        return max(clamped, 0.1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [
                        Color.red.opacity(0.8),
                        Color.orange.opacity(0.9)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: 24 * normalizedHeight)
            .animation(.easeOut(duration: 0.05), value: level)
    }
}

#Preview {
    let monitor = AudioLevelMonitor()
    // Simulate some audio levels for preview
    monitor.levels = (0..<30).map { _ in Float.random(in: 0.1...0.8) }

    return RecordingPillView(audioMonitor: monitor)
        .padding(40)
        .background(Color.gray.opacity(0.3))
}
