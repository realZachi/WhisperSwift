//
//  PermissionManager.swift
//  whisperswift
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
}
