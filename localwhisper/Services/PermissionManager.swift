//
//  PermissionManager.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import AVFoundation

class PermissionManager {
    static let shared = PermissionManager()

    private init() {}
    private let accessibilityPromptedKey = "didPromptAccessibilityAccess"

    // MARK: - Permission Status

    var hasMicrophoneAccess: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    var hasAccessibilityAccess: Bool {
        AXIsProcessTrusted()
    }

    var hasAllPermissions: Bool {
        hasMicrophoneAccess && hasAccessibilityAccess
    }

    // MARK: - Request Permissions

    func requestPermissions() async {
        logToFile("📋 PermissionManager.requestPermissions() starting")
        await requestMicrophoneAccess()
        logToFile("📋 Microphone request done")
        await checkAccessibilityAccess()
        logToFile("📋 Accessibility check done")
    }

    private func requestMicrophoneAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        logToFile("📋 Microphone status: \(status.rawValue)")

        switch status {
        case .notDetermined:
            logToFile("📋 Requesting microphone access...")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            logToFile("📋 Microphone access granted: \(granted)")
            // Don't show blocking alert, just log
        case .denied, .restricted:
            logToFile("⚠️ Microphone access denied/restricted - please enable in System Settings")
        case .authorized:
            logToFile("✅ Microphone access already granted")
        @unknown default:
            break
        }
    }

    private func checkAccessibilityAccess() async {
        logToFile("📋 Checking accessibility access...")
        if !hasAccessibilityAccess {
            logToFile("⚠️ Accessibility NOT granted - prompting system dialog")
            if !UserDefaults.standard.bool(forKey: accessibilityPromptedKey) {
                UserDefaults.standard.set(true, forKey: accessibilityPromptedKey)
                await MainActor.run {
                    _ = requestAccessibilityAccess()
                }
            }
            logToFile("⚠️ Accessibility NOT granted - user should enable in System Settings")
        } else {
            logToFile("✅ Accessibility access already granted")
        }
    }

    // MARK: - Alert Dialogs (kept for menu-triggered use)

    @MainActor
    func showMicrophoneAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "LocalWhisper needs microphone access to record your voice for transcription.\n\nPlease grant microphone access in System Settings > Privacy & Security > Microphone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            openMicrophoneSettings()
        }
    }

    @MainActor
    func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "LocalWhisper needs accessibility access for:\n\n• Global hotkey detection (Fn key)\n• Inserting transcribed text\n\nPlease grant accessibility access in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }

        // Also trigger the system prompt
        _ = requestAccessibilityAccess()
    }

    // MARK: - Open System Settings

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccessibilityAccess() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Permission Change Observation

    /// Start observing permission changes
    func startObserving(onChange: @escaping () -> Void) {
        // Check permissions periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            onChange()
        }
    }
}

// MARK: - Permission Errors

enum PermissionError: Error, LocalizedError {
    case microphoneDenied
    case accessibilityDenied

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access was denied. Please enable it in System Settings."
        case .accessibilityDenied:
            return "Accessibility access was denied. Please enable it in System Settings."
        }
    }
}
