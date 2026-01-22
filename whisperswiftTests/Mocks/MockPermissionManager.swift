//
//  MockPermissionManager.swift
//  whisperswiftTests
//
//  Mock implementation of PermissionManager for testing
//

import Foundation
@testable import whisperswift

class MockPermissionManager {
    var mockHasMicrophoneAccess: Bool = true
    var mockHasAccessibilityAccess: Bool = true
    var requestPermissionsCallCount: Int = 0
    var openMicrophoneSettingsCallCount: Int = 0
    var openAccessibilitySettingsCallCount: Int = 0
    var requestAccessibilityCallCount: Int = 0

    var hasMicrophoneAccess: Bool {
        return mockHasMicrophoneAccess
    }

    var hasAccessibilityAccess: Bool {
        return mockHasAccessibilityAccess
    }

    func requestPermissions() async {
        requestPermissionsCallCount += 1
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    func openMicrophoneSettings() {
        openMicrophoneSettingsCallCount += 1
    }

    func openAccessibilitySettings() {
        openAccessibilitySettingsCallCount += 1
    }

    func requestAccessibilityAccess() -> Bool {
        requestAccessibilityCallCount += 1
        return mockHasAccessibilityAccess
    }

    func reset() {
        mockHasMicrophoneAccess = true
        mockHasAccessibilityAccess = true
        requestPermissionsCallCount = 0
        openMicrophoneSettingsCallCount = 0
        openAccessibilitySettingsCallCount = 0
        requestAccessibilityCallCount = 0
    }
}

// MARK: - Permission Test Scenarios

enum PermissionTestScenario {
    case allGranted
    case microphoneDenied
    case accessibilityDenied
    case allDenied
    case microphoneNotDetermined
    case accessibilityNotDetermined

    func configure(_ mock: MockPermissionManager) {
        switch self {
        case .allGranted:
            mock.mockHasMicrophoneAccess = true
            mock.mockHasAccessibilityAccess = true
        case .microphoneDenied:
            mock.mockHasMicrophoneAccess = false
            mock.mockHasAccessibilityAccess = true
        case .accessibilityDenied:
            mock.mockHasMicrophoneAccess = true
            mock.mockHasAccessibilityAccess = false
        case .allDenied:
            mock.mockHasMicrophoneAccess = false
            mock.mockHasAccessibilityAccess = false
        case .microphoneNotDetermined:
            mock.mockHasMicrophoneAccess = false
            mock.mockHasAccessibilityAccess = true
        case .accessibilityNotDetermined:
            mock.mockHasMicrophoneAccess = true
            mock.mockHasAccessibilityAccess = false
        }
    }
}
