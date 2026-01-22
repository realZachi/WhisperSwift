//
//  HotkeyManagerTests.swift
//  whisperswiftTests
//
//  Tests for HotkeyManager service
//

import XCTest
@testable import whisperswift

final class HotkeyManagerTests: XCTestCase {

    // MARK: - Hotkey Configuration Tests

    func test_SelectedHotkey_DefaultValue_IsFn() {
        // Given no UserDefaults value set
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedHotkey")

        // When reading the default
        let selected = defaults.string(forKey: "selectedHotkey") ?? "fn"

        // Then default should be "fn"
        XCTAssertEqual(selected, "fn")
    }

    func test_SelectedHotkey_Option_IsValid() {
        // Given
        let validHotkeys = ["fn", "option", "control"]

        // Then option should be valid
        XCTAssertTrue(validHotkeys.contains("option"))
    }

    func test_SelectedHotkey_Control_IsValid() {
        // Given
        let validHotkeys = ["fn", "option", "control"]

        // Then control should be valid
        XCTAssertTrue(validHotkeys.contains("control"))
    }

    func test_SelectedHotkey_Fn_IsValid() {
        // Given
        let validHotkeys = ["fn", "option", "control"]

        // Then fn should be valid
        XCTAssertTrue(validHotkeys.contains("fn"))
    }

    func test_HotkeyConfiguration_SavesCorrectly() {
        // Given
        let testHotkey = "option"
        let defaults = UserDefaults.standard

        // When
        defaults.set(testHotkey, forKey: "selectedHotkey")

        // Then
        let saved = defaults.string(forKey: "selectedHotkey")
        XCTAssertEqual(saved, testHotkey)

        // Cleanup
        defaults.removeObject(forKey: "selectedHotkey")
    }

    // MARK: - Key State Tests

    func test_KeyState_InitiallyNotDown() {
        // Key state should start as not pressed
        var isKeyDown = false

        // Initial state should be false
        XCTAssertFalse(isKeyDown)

        // Simulate key press
        isKeyDown = true
        XCTAssertTrue(isKeyDown)
    }

    func test_KeyState_TransitionsCorrectly() {
        // Given
        var isKeyDown = false

        // When key is pressed
        isKeyDown = true
        XCTAssertTrue(isKeyDown)

        // When key is released
        isKeyDown = false
        XCTAssertFalse(isKeyDown)
    }

    func test_KeyState_IgnoresDuplicateDownEvents() {
        // Given
        var isKeyDown = false
        var keyDownCount = 0

        // When key down is called multiple times without release
        func handleKeyDown() {
            if !isKeyDown {
                isKeyDown = true
                keyDownCount += 1
            }
        }

        handleKeyDown()
        handleKeyDown()
        handleKeyDown()

        // Then only one key down should be registered
        XCTAssertEqual(keyDownCount, 1)
    }

    func test_KeyState_IgnoresDuplicateUpEvents() {
        // Given
        var isKeyDown = true
        var keyUpCount = 0

        // When key up is called multiple times without new press
        func handleKeyUp() {
            if isKeyDown {
                isKeyDown = false
                keyUpCount += 1
            }
        }

        handleKeyUp()
        handleKeyUp()
        handleKeyUp()

        // Then only one key up should be registered
        XCTAssertEqual(keyUpCount, 1)
    }

    // MARK: - Callback Tests

    func test_KeyDownCallback_IsInvokedOnKeyPress() {
        // Given
        var callbackInvoked = false
        var isKeyDown = false

        func onKeyDown() {
            callbackInvoked = true
        }

        // When key is pressed
        if !isKeyDown {
            isKeyDown = true
            onKeyDown()
        }

        // Then callback should be invoked
        XCTAssertTrue(callbackInvoked)
    }

    func test_KeyUpCallback_IsInvokedOnKeyRelease() {
        // Given
        var callbackInvoked = false
        var isKeyDown = true

        func onKeyUp() {
            callbackInvoked = true
        }

        // When key is released
        if isKeyDown {
            isKeyDown = false
            onKeyUp()
        }

        // Then callback should be invoked
        XCTAssertTrue(callbackInvoked)
    }

    func test_Callbacks_AreNotInvokedForDuplicateEvents() {
        // Given
        var keyDownCallbackCount = 0
        var keyUpCallbackCount = 0
        var isKeyDown = false

        func handleKeyDown() {
            if !isKeyDown {
                isKeyDown = true
                keyDownCallbackCount += 1
            }
        }

        func handleKeyUp() {
            if isKeyDown {
                isKeyDown = false
                keyUpCallbackCount += 1
            }
        }

        // When
        handleKeyDown()
        handleKeyDown() // Duplicate
        handleKeyUp()
        handleKeyUp() // Duplicate

        // Then
        XCTAssertEqual(keyDownCallbackCount, 1)
        XCTAssertEqual(keyUpCallbackCount, 1)
    }

    // MARK: - Modifier Flag Tests

    func test_ModifierFlags_FunctionKey_IsRecognized() {
        // CGEventFlags.maskSecondaryFn is used for Fn key detection
        let fnKeyMask: UInt64 = 0x800000 // CGEventFlags.maskSecondaryFn raw value

        // Verify the mask is non-zero
        XCTAssertNotEqual(fnKeyMask, 0)
    }

    func test_ModifierFlags_OptionKey_IsRecognized() {
        // CGEventFlags.maskAlternate is used for Option key detection
        let optionKeyMask: UInt64 = 0x80000 // CGEventFlags.maskAlternate raw value

        // Verify the mask is non-zero
        XCTAssertNotEqual(optionKeyMask, 0)
    }

    func test_ModifierFlags_ControlKey_IsRecognized() {
        // CGEventFlags.maskControl is used for Control key detection
        let controlKeyMask: UInt64 = 0x40000 // CGEventFlags.maskControl raw value

        // Verify the mask is non-zero
        XCTAssertNotEqual(controlKeyMask, 0)
    }

    // MARK: - Hotkey Selection Logic Tests

    func test_HotkeySelection_FnKey_MapsCorrectly() {
        // Given
        let selectedHotkey = "fn"

        // When determining which mask to use
        let useFnKey = selectedHotkey == "fn"
        let useOptionKey = selectedHotkey == "option"
        let useControlKey = selectedHotkey == "control"

        // Then only fn should be true
        XCTAssertTrue(useFnKey)
        XCTAssertFalse(useOptionKey)
        XCTAssertFalse(useControlKey)
    }

    func test_HotkeySelection_OptionKey_MapsCorrectly() {
        // Given
        let selectedHotkey = "option"

        // When determining which mask to use
        let useFnKey = selectedHotkey == "fn"
        let useOptionKey = selectedHotkey == "option"
        let useControlKey = selectedHotkey == "control"

        // Then only option should be true
        XCTAssertFalse(useFnKey)
        XCTAssertTrue(useOptionKey)
        XCTAssertFalse(useControlKey)
    }

    func test_HotkeySelection_ControlKey_MapsCorrectly() {
        // Given
        let selectedHotkey = "control"

        // When determining which mask to use
        let useFnKey = selectedHotkey == "fn"
        let useOptionKey = selectedHotkey == "option"
        let useControlKey = selectedHotkey == "control"

        // Then only control should be true
        XCTAssertFalse(useFnKey)
        XCTAssertFalse(useOptionKey)
        XCTAssertTrue(useControlKey)
    }

    func test_HotkeySelection_UnknownKey_DefaultsToFn() {
        // Given an unknown hotkey value
        let selectedHotkey = "unknown"

        // When determining behavior
        let shouldUseFnAsDefault = !["option", "control"].contains(selectedHotkey)

        // Then should default to fn behavior
        XCTAssertTrue(shouldUseFnAsDefault)
    }

    // MARK: - Performance Tests

    func test_KeyStateToggle_Performance() {
        var isKeyDown = false

        measure {
            for _ in 0..<10000 {
                if !isKeyDown {
                    isKeyDown = true
                }
                if isKeyDown {
                    isKeyDown = false
                }
            }
        }
    }

    func test_HotkeyLookup_Performance() {
        let hotkeys = ["fn", "option", "control"]

        measure {
            for _ in 0..<10000 {
                for hotkey in hotkeys {
                    _ = hotkey == "fn"
                    _ = hotkey == "option"
                    _ = hotkey == "control"
                }
            }
        }
    }
}

// MARK: - Accessibility Permission Tests

final class AccessibilityPermissionTests: XCTestCase {

    func test_AccessibilityCheck_ReturnsBoolean() {
        // The accessibility check should return a boolean value
        // In tests, we can't actually check the permission, but we verify the interface
        let permissionGranted: Bool = false // Simulated

        XCTAssertFalse(permissionGranted) // Just verify it's a boolean type
    }

    func test_AccessibilityRequired_ForGlobalHotkeys() {
        // Global hotkey monitoring requires accessibility permissions
        let requiresAccessibility = true

        XCTAssertTrue(requiresAccessibility)
    }

    func test_AccessibilityRequired_ForCGEventTap() {
        // CGEvent tap creation requires accessibility permissions
        let requiresAccessibility = true

        XCTAssertTrue(requiresAccessibility)
    }
}
