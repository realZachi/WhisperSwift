//
//  RecordingPillController.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import SwiftUI

@Observable
final class RecordingPillStateManager {
    var state: RecordingPillState = .recording
}

class RecordingPillController {
    private var pillPanel: NSPanel?
    let audioMonitor = AudioLevelMonitor()
    let stateManager = RecordingPillStateManager()

    private let panelWidth: CGFloat = 280
    private let panelHeight: CGFloat = 90

    init() {
        setupPanel()
    }

    private func setupPanel() {
        let hostingView = NSHostingView(rootView: PillContainerView(
            audioMonitor: audioMonitor,
            stateManager: stateManager
        ))
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.contentView = hostingView

        pillPanel = panel
    }

    func show() {
        guard let panel = pillPanel, let screen = NSScreen.main else { return }

        stateManager.state = .recording

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let xPos = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
        let yPos = screenFrame.origin.y + 60

        panel.setFrameOrigin(NSPoint(x: xPos, y: yPos))

        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        logToFile("Recording indicator shown")
    }

    func transitionToProcessing() {
        DispatchQueue.main.async { [weak self] in
            self?.stateManager.state = .processing
        }
        logToFile("Transitioned to processing state")
    }

    func transitionToSaved(text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.stateManager.state = .savedToClipboard(text: text)
        }
        logToFile("Transitioned to saved state")
    }

    func hide() {
        guard let panel = pillPanel else { return }

        audioMonitor.reset()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })

        logToFile("Recording indicator hidden")
    }

    func updateLevel(_ level: Float) {
        audioMonitor.update(level: level)
    }
}

// MARK: - Container View for Observable State

private struct PillContainerView: View {
    var audioMonitor: AudioLevelMonitor
    var stateManager: RecordingPillStateManager

    var body: some View {
        let state = stateManager.state
        RecordingPillView(audioMonitor: audioMonitor, state: state)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
