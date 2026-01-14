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

    // MARK: - Permission Status

    var hasMicrophoneAccess: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    var hasAccessibilityAccess: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    var hasAllPermissions: Bool {
        hasMicrophoneAccess && hasAccessibilityAccess
    }

    // MARK: - Request Permissions

    func requestPermissions() async {
        await requestMicrophoneAccess()
        await checkAccessibilityAccess()
    }

    private func requestMicrophoneAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                await showMicrophoneAlert()
            }
        case .denied, .restricted:
            await showMicrophoneAlert()
        case .authorized:
            print("Microphone access already granted")
        @unknown default:
            break
        }
    }

    private func checkAccessibilityAccess() async {
        if !hasAccessibilityAccess {
            await showAccessibilityAlert()
        } else {
            print("Accessibility access already granted")
        }
    }

    // MARK: - Alert Dialogs

    @MainActor
    private func showMicrophoneAlert() {
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
    private func showAccessibilityAlert() {
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
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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
