//
//  RecordingPillController.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import SwiftUI

class RecordingPillController {
    private var pillPanel: NSPanel?
    let audioMonitor = AudioLevelMonitor()

    init() {
        setupPanel()
    }

    private func setupPanel() {
        // Create the SwiftUI view
        let pillView = RecordingPillView(audioMonitor: audioMonitor)

        // Create hosting view
        let hostingView = NSHostingView(rootView: pillView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 240, height: 64)

        // Create borderless panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure panel to float above everything
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.contentView = hostingView

        self.pillPanel = panel
    }

    func show() {
        guard let panel = pillPanel, let screen = NSScreen.main else { return }

        // Position at bottom center of screen
        let screenFrame = screen.visibleFrame
        let panelWidth = panel.frame.width
        let xPos = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let yPos = screenFrame.origin.y + 60 // 60pt from bottom

        panel.setFrameOrigin(NSPoint(x: xPos, y: yPos))

        // Fade in animation
        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        logToFile("🎙️ Recording pill shown")
    }

    func hide() {
        guard let panel = pillPanel else { return }

        // Reset audio levels
        audioMonitor.reset()

        // Fade out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })

        logToFile("🎙️ Recording pill hidden")
    }

    func updateLevel(_ level: Float) {
        audioMonitor.update(level: level)
    }
}
