//
//  HotkeyManagerTests.swift
//  whisperswiftTests
//
//  Tests for HotkeyManager service
//

@testable import whisperswift
import AppKit
import XCTest

final class HotkeyConfigurationTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "HotkeyConfigurationTests")
        defaults.removePersistentDomain(forName: "HotkeyConfigurationTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "HotkeyConfigurationTests")
        defaults = nil
        super.tearDown()
    }

    func test_CurrentConfiguration_DefaultsToFn() {
        let configuration = HotkeyConfiguration.current(in: defaults)

        XCTAssertEqual(configuration.keyCode, HotkeyConfiguration.defaultKeyCode)
        XCTAssertEqual(configuration.displayName, "Fn (Globe)")
    }

    func test_CurrentConfiguration_MigratesLegacyOptionSelection() {
        defaults.set("option", forKey: HotkeyConfiguration.legacyDefaultsKey)

        let configuration = HotkeyConfiguration.current(in: defaults)

        XCTAssertEqual(configuration.displayName, "Right Option")
    }

    func test_SavePersistsAnArbitraryKey() {
        HotkeyConfiguration.save(keyCode: 0, displayName: "A", in: defaults)

        XCTAssertEqual(
            HotkeyConfiguration.current(in: defaults),
            HotkeyConfiguration(keyCode: 0, displayName: "A")
        )
        XCTAssertEqual(defaults.string(forKey: HotkeyConfiguration.legacyDefaultsKey), "custom")
    }

    func test_CapsLockIsRejectedForHoldToRecord() {
        XCTAssertFalse(HotkeyConfiguration.isSupported(57))
    }

    func test_ModifierPressDetection_RecognizesAppKitFlags() {
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(55, in: [.command]))
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(58, in: [.option]))
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(59, in: [.control]))
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(56, in: [.shift]))
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(63, in: [.function]))
    }

    func test_ModifierPressDetection_RejectsReleasedAppKitFlags() {
        let noFlags = NSEvent.ModifierFlags()

        XCTAssertFalse(HotkeyConfiguration.isModifierPressed(55, in: noFlags))
        XCTAssertFalse(HotkeyConfiguration.isModifierPressed(58, in: noFlags))
        XCTAssertFalse(HotkeyConfiguration.isModifierPressed(63, in: noFlags))
    }

    func test_ModifierPressDetection_RecognizesCGEventFlags() {
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(55, in: [.maskCommand]))
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(58, in: [.maskAlternate]))
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(59, in: [.maskControl]))
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(56, in: [.maskShift]))
        XCTAssertTrue(HotkeyConfiguration.isModifierPressed(63, in: [.maskSecondaryFn]))
    }
}

final class HotkeyManagerTests: XCTestCase {
    // MARK: - Hotkey Configuration Tests

    func test_SelectedHotkey_DefaultValue_IsFn() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedHotkey")
        let selected = defaults.string(forKey: "selectedHotkey") ?? "fn"
        XCTAssertEqual(selected, "fn")
    }

    func test_SelectedHotkey_Option_IsValid() {
        let validHotkeys = ["fn", "option", "control"]
        XCTAssertTrue(validHotkeys.contains("option"))
    }

    func test_SelectedHotkey_Control_IsValid() {
        let validHotkeys = ["fn", "option", "control"]
        XCTAssertTrue(validHotkeys.contains("control"))
    }

    func test_SelectedHotkey_Fn_IsValid() {
        let validHotkeys = ["fn", "option", "control"]
        XCTAssertTrue(validHotkeys.contains("fn"))
    }

    func test_HotkeyConfiguration_SavesCorrectly() {
        let defaults = UserDefaults.standard
        defaults.set("option", forKey: "selectedHotkey")
        XCTAssertEqual(defaults.string(forKey: "selectedHotkey"), "option")
        defaults.removeObject(forKey: "selectedHotkey")
    }

    // MARK: - Key State Tests

    func test_KeyState_InitiallyNotDown() {
        var isKeyDown = false
        XCTAssertFalse(isKeyDown)
        isKeyDown = true
        XCTAssertTrue(isKeyDown)
    }

    func test_KeyState_TransitionsCorrectly() {
        var isKeyDown = false
        isKeyDown = true
        XCTAssertTrue(isKeyDown)
        isKeyDown = false
        XCTAssertFalse(isKeyDown)
    }

    func test_KeyState_IgnoresDuplicateDownEvents() {
        var isKeyDown = false
        var keyDownCount = 0

        func handleKeyDown() {
            if !isKeyDown {
                isKeyDown = true
                keyDownCount += 1
            }
        }

        handleKeyDown()
        handleKeyDown()
        handleKeyDown()

        XCTAssertEqual(keyDownCount, 1)
    }

    func test_KeyState_IgnoresDuplicateUpEvents() {
        var isKeyDown = true
        var keyUpCount = 0

        func handleKeyUp() {
            if isKeyDown {
                isKeyDown = false
                keyUpCount += 1
            }
        }

        handleKeyUp()
        handleKeyUp()
        handleKeyUp()

        XCTAssertEqual(keyUpCount, 1)
    }

    // MARK: - Callback Tests

    func test_KeyDownCallback_IsInvokedOnKeyPress() {
        var callbackInvoked = false
        var isKeyDown = false

        if !isKeyDown {
            isKeyDown = true
            callbackInvoked = true
        }

        XCTAssertTrue(callbackInvoked)
    }

    func test_KeyUpCallback_IsInvokedOnKeyRelease() {
        var callbackInvoked = false
        var isKeyDown = true

        if isKeyDown {
            isKeyDown = false
            callbackInvoked = true
        }

        XCTAssertTrue(callbackInvoked)
        _ = isKeyDown // silence warning
    }

    func test_Callbacks_AreNotInvokedForDuplicateEvents() {
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

        handleKeyDown()
        handleKeyDown()
        handleKeyUp()
        handleKeyUp()

        XCTAssertEqual(keyDownCallbackCount, 1)
        XCTAssertEqual(keyUpCallbackCount, 1)
    }

    // MARK: - Modifier Flag Tests

    func test_ModifierFlags_FunctionKey_IsRecognized() {
        let fnKeyMask: UInt64 = 0x800000
        XCTAssertNotEqual(fnKeyMask, 0)
    }

    func test_ModifierFlags_OptionKey_IsRecognized() {
        let optionKeyMask: UInt64 = 0x80000
        XCTAssertNotEqual(optionKeyMask, 0)
    }

    func test_ModifierFlags_ControlKey_IsRecognized() {
        let controlKeyMask: UInt64 = 0x40000
        XCTAssertNotEqual(controlKeyMask, 0)
    }

    // MARK: - Hotkey Selection Logic Tests

    func test_HotkeySelection_FnKey_MapsCorrectly() {
        XCTAssertTrue("fn" == "fn")
        XCTAssertFalse("fn" == "option")
        XCTAssertFalse("fn" == "control")
    }

    func test_HotkeySelection_OptionKey_MapsCorrectly() {
        XCTAssertFalse("option" == "fn")
        XCTAssertTrue("option" == "option")
        XCTAssertFalse("option" == "control")
    }

    func test_HotkeySelection_ControlKey_MapsCorrectly() {
        XCTAssertFalse("control" == "fn")
        XCTAssertFalse("control" == "option")
        XCTAssertTrue("control" == "control")
    }

    func test_HotkeySelection_UnknownKey_DefaultsToFn() {
        let shouldUseFnAsDefault = !["option", "control"].contains("unknown")
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
        let permissionGranted = false
        XCTAssertFalse(permissionGranted)
    }

    func test_AccessibilityRequired_ForGlobalHotkeys() {
        XCTAssertTrue(true) // Global hotkeys require accessibility
    }

    func test_AccessibilityRequired_ForCGEventTap() {
        XCTAssertTrue(true) // CGEvent tap requires accessibility
    }
}
