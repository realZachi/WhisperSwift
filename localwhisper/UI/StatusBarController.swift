//
//  StatusBarController.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem
    private var settingsWindow: NSWindow?

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

    @objc private func openSettings() {
        // Open the Settings window via SwiftUI
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
