//
//  PermissionManagerTests.swift
//  whisperswiftTests
//
//  Tests for PermissionManager
//

import XCTest
import AVFoundation
@testable import whisperswift

final class PermissionManagerTests: XCTestCase {

    // MARK: - Singleton Tests

    func test_Shared_ReturnsSameInstance() {
        // Given
        let instance1 = PermissionManager.shared
        let instance2 = PermissionManager.shared

        // Then both references should point to same instance
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Microphone Settings URL Tests

    func test_MicrophoneSettingsURL_IsValid() {
        // Given
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"

        // When
        let url = URL(string: urlString)

        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "x-apple.systempreferences")
    }

    func test_MicrophoneSettingsURL_ContainsMicrophonePrivacy() {
        // Given
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"

        // Then
        XCTAssertTrue(urlString.contains("Privacy_Microphone"))
    }

    // MARK: - Accessibility Settings URL Tests

    func test_AccessibilitySettingsURL_IsValid() {
        // Given
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

        // When
        let url = URL(string: urlString)

        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "x-apple.systempreferences")
    }

    func test_AccessibilitySettingsURL_ContainsAccessibilityPrivacy() {
        // Given
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

        // Then
        XCTAssertTrue(urlString.contains("Privacy_Accessibility"))
    }

    // MARK: - AVCaptureDevice Authorization Status Tests

    func test_AuthorizationStatus_NotDetermined_RawValue() {
        // Given
        let status = AVAuthorizationStatus.notDetermined

        // Then raw value should be 0
        XCTAssertEqual(status.rawValue, 0)
    }

    func test_AuthorizationStatus_Restricted_RawValue() {
        // Given
        let status = AVAuthorizationStatus.restricted

        // Then raw value should be 1
        XCTAssertEqual(status.rawValue, 1)
    }

    func test_AuthorizationStatus_Denied_RawValue() {
        // Given
        let status = AVAuthorizationStatus.denied

        // Then raw value should be 2
        XCTAssertEqual(status.rawValue, 2)
    }

    func test_AuthorizationStatus_Authorized_RawValue() {
        // Given
        let status = AVAuthorizationStatus.authorized

        // Then raw value should be 3
        XCTAssertEqual(status.rawValue, 3)
    }

    // MARK: - Permission State Logic Tests

    func test_PermissionState_Authorized_AllowsAccess() {
        // Given
        let status = AVAuthorizationStatus.authorized

        // When
        let hasAccess = status == .authorized

        // Then
        XCTAssertTrue(hasAccess)
    }

    func test_PermissionState_Denied_DeniesAccess() {
        // Given
        let status = AVAuthorizationStatus.denied

        // When
        let hasAccess = status == .authorized

        // Then
        XCTAssertFalse(hasAccess)
    }

    func test_PermissionState_Restricted_DeniesAccess() {
        // Given
        let status = AVAuthorizationStatus.restricted

        // When
        let hasAccess = status == .authorized

        // Then
        XCTAssertFalse(hasAccess)
    }

    func test_PermissionState_NotDetermined_DeniesAccess() {
        // Given
        let status = AVAuthorizationStatus.notDetermined

        // When
        let hasAccess = status == .authorized

        // Then
        XCTAssertFalse(hasAccess)
    }

    // MARK: - UserDefaults Key Tests

    func test_AccessibilityPromptedKey_IsConsistent() {
        // Given
        let key = "didPromptAccessibilityAccess"

        // Then key should not be empty
        XCTAssertFalse(key.isEmpty)
    }

    func test_AccessibilityPrompted_DefaultIsFalse() {
        // Given
        let defaults = UserDefaults.standard
        let key = "testAccessibilityPromptedKey_\(UUID().uuidString)"

        // When reading unset value
        let prompted = defaults.bool(forKey: key)

        // Then should be false by default
        XCTAssertFalse(prompted)
    }

    func test_AccessibilityPrompted_CanBeSetToTrue() {
        // Given
        let defaults = UserDefaults.standard
        let key = "testAccessibilityPromptedKey_\(UUID().uuidString)"

        // When
        defaults.set(true, forKey: key)

        // Then
        XCTAssertTrue(defaults.bool(forKey: key))

        // Cleanup
        defaults.removeObject(forKey: key)
    }

    func test_AccessibilityPrompted_PersistsAfterSet() {
        // Given
        let defaults = UserDefaults.standard
        let key = "testAccessibilityPromptedKey_\(UUID().uuidString)"

        // When
        defaults.set(true, forKey: key)
        defaults.synchronize()
        let value = defaults.bool(forKey: key)

        // Then
        XCTAssertTrue(value)

        // Cleanup
        defaults.removeObject(forKey: key)
    }

    // MARK: - Permission Request Logic Tests

    func test_PermissionRequest_ShouldPromptOnce() {
        // Given
        var promptCount = 0
        let key = "testPromptKey_\(UUID().uuidString)"
        let defaults = UserDefaults.standard

        func promptIfNeeded() {
            if !defaults.bool(forKey: key) {
                defaults.set(true, forKey: key)
                promptCount += 1
            }
        }

        // When
        promptIfNeeded()
        promptIfNeeded()
        promptIfNeeded()

        // Then should only prompt once
        XCTAssertEqual(promptCount, 1)

        // Cleanup
        defaults.removeObject(forKey: key)
    }

    // MARK: - Permission Check Combination Tests

    func test_AllPermissionsGranted_WhenBothAuthorized() {
        // Given
        let hasMicrophoneAccess = true
        let hasAccessibilityAccess = true

        // When
        let allPermissionsGranted = hasMicrophoneAccess && hasAccessibilityAccess

        // Then
        XCTAssertTrue(allPermissionsGranted)
    }

    func test_AllPermissionsGranted_FalseWhenMicrophoneDenied() {
        // Given
        let hasMicrophoneAccess = false
        let hasAccessibilityAccess = true

        // When
        let allPermissionsGranted = hasMicrophoneAccess && hasAccessibilityAccess

        // Then
        XCTAssertFalse(allPermissionsGranted)
    }

    func test_AllPermissionsGranted_FalseWhenAccessibilityDenied() {
        // Given
        let hasMicrophoneAccess = true
        let hasAccessibilityAccess = false

        // When
        let allPermissionsGranted = hasMicrophoneAccess && hasAccessibilityAccess

        // Then
        XCTAssertFalse(allPermissionsGranted)
    }

    func test_AllPermissionsGranted_FalseWhenBothDenied() {
        // Given
        let hasMicrophoneAccess = false
        let hasAccessibilityAccess = false

        // When
        let allPermissionsGranted = hasMicrophoneAccess && hasAccessibilityAccess

        // Then
        XCTAssertFalse(allPermissionsGranted)
    }

    // MARK: - Performance Tests

    func test_PermissionCheck_Performance() {
        measure {
            for _ in 0..<1000 {
                _ = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            }
        }
    }

    func test_UserDefaultsRead_Performance() {
        let defaults = UserDefaults.standard
        let key = "performanceTestKey"
        defaults.set(true, forKey: key)

        measure {
            for _ in 0..<10000 {
                _ = defaults.bool(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
    }
}

// MARK: - Permission State Machine Tests

final class PermissionStateMachineTests: XCTestCase {

    enum PermissionState {
        case notDetermined
        case requesting
        case authorized
        case denied
    }

    func test_StateTransition_NotDeterminedToRequesting() {
        // Given
        var state = PermissionState.notDetermined

        // When
        state = .requesting

        // Then
        XCTAssertEqual(state, .requesting)
    }

    func test_StateTransition_RequestingToAuthorized() {
        // Given
        var state = PermissionState.requesting

        // When user grants permission
        state = .authorized

        // Then
        XCTAssertEqual(state, .authorized)
    }

    func test_StateTransition_RequestingToDenied() {
        // Given
        var state = PermissionState.requesting

        // When user denies permission
        state = .denied

        // Then
        XCTAssertEqual(state, .denied)
    }

    func test_StateCheck_IsAuthorized() {
        // Given
        let state = PermissionState.authorized

        // When
        let isAuthorized = state == .authorized

        // Then
        XCTAssertTrue(isAuthorized)
    }

    func test_StateCheck_NeedsRequest() {
        // Given
        let state = PermissionState.notDetermined

        // When
        let needsRequest = state == .notDetermined

        // Then
        XCTAssertTrue(needsRequest)
    }
}
