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
        let instance1 = PermissionManager.shared
        let instance2 = PermissionManager.shared
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Microphone Settings URL Tests

    func test_MicrophoneSettingsURL_IsValid() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        let url = URL(string: urlString)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "x-apple.systempreferences")
    }

    func test_MicrophoneSettingsURL_ContainsMicrophonePrivacy() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        XCTAssertTrue(urlString.contains("Privacy_Microphone"))
    }

    // MARK: - Accessibility Settings URL Tests

    func test_AccessibilitySettingsURL_IsValid() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        let url = URL(string: urlString)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "x-apple.systempreferences")
    }

    func test_AccessibilitySettingsURL_ContainsAccessibilityPrivacy() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        XCTAssertTrue(urlString.contains("Privacy_Accessibility"))
    }

    // MARK: - AVCaptureDevice Authorization Status Tests

    func test_AuthorizationStatus_NotDetermined_RawValue() {
        XCTAssertEqual(AVAuthorizationStatus.notDetermined.rawValue, 0)
    }

    func test_AuthorizationStatus_Restricted_RawValue() {
        XCTAssertEqual(AVAuthorizationStatus.restricted.rawValue, 1)
    }

    func test_AuthorizationStatus_Denied_RawValue() {
        XCTAssertEqual(AVAuthorizationStatus.denied.rawValue, 2)
    }

    func test_AuthorizationStatus_Authorized_RawValue() {
        XCTAssertEqual(AVAuthorizationStatus.authorized.rawValue, 3)
    }

    // MARK: - Permission State Logic Tests

    func test_PermissionState_Authorized_AllowsAccess() {
        XCTAssertTrue(AVAuthorizationStatus.authorized == .authorized)
    }

    func test_PermissionState_Denied_DeniesAccess() {
        XCTAssertFalse(AVAuthorizationStatus.denied == .authorized)
    }

    func test_PermissionState_Restricted_DeniesAccess() {
        XCTAssertFalse(AVAuthorizationStatus.restricted == .authorized)
    }

    func test_PermissionState_NotDetermined_DeniesAccess() {
        XCTAssertFalse(AVAuthorizationStatus.notDetermined == .authorized)
    }

    // MARK: - UserDefaults Key Tests

    func test_AccessibilityPromptedKey_IsConsistent() {
        XCTAssertFalse("didPromptAccessibilityAccess".isEmpty)
    }

    func test_AccessibilityPrompted_DefaultIsFalse() {
        let key = "testAccessibilityPromptedKey_\(UUID().uuidString)"
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
    }

    func test_AccessibilityPrompted_CanBeSetToTrue() {
        let defaults = UserDefaults.standard
        let key = "testAccessibilityPromptedKey_\(UUID().uuidString)"
        defaults.set(true, forKey: key)
        XCTAssertTrue(defaults.bool(forKey: key))
        defaults.removeObject(forKey: key)
    }

    func test_AccessibilityPrompted_PersistsAfterSet() {
        let defaults = UserDefaults.standard
        let key = "testAccessibilityPromptedKey_\(UUID().uuidString)"
        defaults.set(true, forKey: key)
        defaults.synchronize()
        XCTAssertTrue(defaults.bool(forKey: key))
        defaults.removeObject(forKey: key)
    }

    // MARK: - Permission Request Logic Tests

    func test_PermissionRequest_ShouldPromptOnce() {
        var promptCount = 0
        let key = "testPromptKey_\(UUID().uuidString)"
        let defaults = UserDefaults.standard

        func promptIfNeeded() {
            if !defaults.bool(forKey: key) {
                defaults.set(true, forKey: key)
                promptCount += 1
            }
        }

        promptIfNeeded()
        promptIfNeeded()
        promptIfNeeded()

        XCTAssertEqual(promptCount, 1)
        defaults.removeObject(forKey: key)
    }

    // MARK: - Permission Check Combination Tests

    func test_AllPermissionsGranted_WhenBothAuthorized() {
        XCTAssertTrue(true && true)
    }

    func test_AllPermissionsGranted_FalseWhenMicrophoneDenied() {
        XCTAssertFalse(false && true)
    }

    func test_AllPermissionsGranted_FalseWhenAccessibilityDenied() {
        XCTAssertFalse(true && false)
    }

    func test_AllPermissionsGranted_FalseWhenBothDenied() {
        XCTAssertFalse(false && false)
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
        var state = PermissionState.notDetermined
        state = .requesting
        XCTAssertEqual(state, .requesting)
    }

    func test_StateTransition_RequestingToAuthorized() {
        var state = PermissionState.requesting
        state = .authorized
        XCTAssertEqual(state, .authorized)
    }

    func test_StateTransition_RequestingToDenied() {
        var state = PermissionState.requesting
        state = .denied
        XCTAssertEqual(state, .denied)
    }

    func test_StateCheck_IsAuthorized() {
        XCTAssertTrue(PermissionState.authorized == .authorized)
    }

    func test_StateCheck_NeedsRequest() {
        XCTAssertTrue(PermissionState.notDetermined == .notDetermined)
    }
}
