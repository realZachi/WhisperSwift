//
//  StatusBarController.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import Combine
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    enum RecordingState {
        case idle
        case recording
        case processing
    }

    var state: RecordingState = .idle {
        didSet {
            updateIcon()
        }
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton()
        setupMenu()
        observeModelStatus()
    }

    private func setupButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "LocalWhisper")
            button.image?.isTemplate = true
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Status indicator (disabled item)
        let statusMenuItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)

        let modelMenuItem = NSMenuItem(title: "Model: Not downloaded", action: nil, keyEquivalent: "")
        modelMenuItem.isEnabled = false
        modelMenuItem.tag = 101
        menu.addItem(modelMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Hotkey info
        let hotkeyInfo = NSMenuItem(title: "Hold Fn to record", action: nil, keyEquivalent: "")
        hotkeyInfo.isEnabled = false
        menu.addItem(hotkeyInfo)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit LocalWhisper", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateIcon() {
        let symbolName: String
        let statusText: String

        switch state {
        case .idle:
            symbolName = "waveform"
            statusText = "Ready"
        case .recording:
            symbolName = "waveform.circle.fill"
            statusText = "Recording..."
        case .processing:
            symbolName = "ellipsis.circle"
            statusText = "Processing..."
        }

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            button.image?.isTemplate = true
        }

        // Update status menu item
        if let menu = statusItem.menu,
           let statusMenuItem = menu.item(withTag: 100) {
            statusMenuItem.title = statusText
        }
    }

    private func observeModelStatus() {
        WhisperModelStatus.shared.$phase
            .combineLatest(
                WhisperModelStatus.shared.$progressFraction,
                WhisperModelStatus.shared.$message,
                WhisperModelStatus.shared.$modelName
            )
            .receive(on: RunLoop.main)
            .sink { [weak self] phase, progress, message, modelName in
                self?.updateModelMenuItem(phase: phase, progress: progress, message: message, modelName: modelName)
            }
            .store(in: &cancellables)
    }

    private func updateModelMenuItem(
        phase: WhisperModelStatus.Phase,
        progress: Double?,
        message: String,
        modelName: String
    ) {
        let text: String
        switch phase {
        case .ready:
            text = "Model: \(modelName) ready"
        case .downloading:
            let percent = Int((progress ?? 0) * 100)
            text = "Model: downloading \(percent)%"
        case .failed:
            text = "Model: download failed"
        case .idle:
            text = "Model: not downloaded"
        }

        if let menu = statusItem.menu,
           let modelMenuItem = menu.item(withTag: 101) {
            modelMenuItem.title = text
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.isReleasedWhenClosed = false
            window.contentViewController = hostingController
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
