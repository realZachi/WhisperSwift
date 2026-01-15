//
//  StatusBarController.swift
//  whisperswift
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
        observeDefaults()
        updateApiMenuItem()
        updateHotkeyMenuItem()
        updateIcon()
    }

    private func setupButton() {
        updateIcon()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Status indicator (disabled item)
        let statusMenuItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)

        let apiMenuItem = NSMenuItem(title: "Groq API: key missing", action: nil, keyEquivalent: "")
        apiMenuItem.isEnabled = false
        apiMenuItem.tag = 101
        menu.addItem(apiMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Hotkey info
        let hotkeyInfo = NSMenuItem(title: "Hold Fn to record", action: nil, keyEquivalent: "")
        hotkeyInfo.isEnabled = false
        hotkeyInfo.tag = 102
        menu.addItem(hotkeyInfo)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit WhisperSwift", action: #selector(quit), keyEquivalent: "q")
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
            let image = customStatusBarImage(for: state) ??
                NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            image?.isTemplate = true
            button.image = image
        }

        // Update status menu item
        if let menu = statusItem.menu,
           let statusMenuItem = menu.item(withTag: 100) {
            statusMenuItem.title = statusText
        }
    }

    private func customStatusBarImage(for state: RecordingState) -> NSImage? {
        switch state {
        case .idle:
            return NSImage(named: "StatusBarIcon")
        case .recording:
            return NSImage(named: "StatusBarIconRecording") ?? NSImage(named: "StatusBarIcon")
        case .processing:
            return NSImage(named: "StatusBarIconProcessing") ?? NSImage(named: "StatusBarIcon")
        }
    }

    private func observeDefaults() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateApiMenuItem()
                self?.updateHotkeyMenuItem()
            }
            .store(in: &cancellables)
    }

    private func updateApiMenuItem() {
        let storedKey = UserDefaults.standard.string(forKey: "groqApiKey") ?? ""
        let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
        let trimmed = storedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let isConfigured = !trimmed.isEmpty || !envKey.isEmpty
        let text = isConfigured ? "Groq API: key set" : "Groq API: key missing"

        if let menu = statusItem.menu,
           let apiMenuItem = menu.item(withTag: 101) {
            apiMenuItem.title = text
        }
    }

    private func updateHotkeyMenuItem() {
        let hotkey = UserDefaults.standard.string(forKey: "selectedHotkey") ?? "fn"
        let keyName: String

        switch hotkey {
        case "option":
            keyName = "Option"
        case "control":
            keyName = "Control"
        default:
            keyName = "Fn"
        }

        let title = "Hold \(keyName) to record, double-tap to lock"

        if let menu = statusItem.menu,
           let hotkeyMenuItem = menu.item(withTag: 102) {
            hotkeyMenuItem.title = title
        }
    }

    @objc func openSettings() {
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
