//
//  HotkeyConfiguration.swift
//  whisperswift
//

import AppKit
import Carbon

struct HotkeyConfiguration: Equatable {
    static let keyCodeDefaultsKey = "selectedHotkeyKeyCode"
    static let displayNameDefaultsKey = "selectedHotkeyDisplayName"
    static let legacyDefaultsKey = "selectedHotkey"
    static let defaultKeyCode = UInt16(kVK_Function)

    let keyCode: UInt16
    let displayName: String

    static var current: HotkeyConfiguration {
        current(in: .standard)
    }

    static func current(in defaults: UserDefaults) -> HotkeyConfiguration {
        if defaults.object(forKey: keyCodeDefaultsKey) != nil,
           let keyCode = UInt16(exactly: defaults.integer(forKey: keyCodeDefaultsKey)),
           isSupported(keyCode) {
            let storedName = defaults.string(forKey: displayNameDefaultsKey) ?? ""
            let name = storedName.isEmpty ? displayName(for: keyCode) : storedName
            return HotkeyConfiguration(keyCode: keyCode, displayName: name)
        }

        let legacyHotkey = defaults.string(forKey: legacyDefaultsKey) ?? "fn"
        let keyCode: UInt16

        switch legacyHotkey {
        case "option":
            keyCode = UInt16(kVK_RightOption)
        case "control":
            keyCode = UInt16(kVK_RightControl)
        default:
            keyCode = defaultKeyCode
        }

        return HotkeyConfiguration(keyCode: keyCode, displayName: displayName(for: keyCode))
    }

    static func save(
        keyCode: UInt16,
        displayName: String,
        in defaults: UserDefaults = .standard
    ) {
        guard isSupported(keyCode) else { return }

        defaults.set(Int(keyCode), forKey: keyCodeDefaultsKey)
        defaults.set(displayName, forKey: displayNameDefaultsKey)
        defaults.set(legacyValue(for: keyCode), forKey: legacyDefaultsKey)
    }

    static func isModifier(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Command,
             kVK_Shift,
             kVK_Option,
             kVK_Control,
             kVK_RightCommand,
             kVK_RightShift,
             kVK_RightOption,
             kVK_RightControl,
             kVK_Function:
            return true
        default:
            return false
        }
    }

    static func isSupported(_ keyCode: UInt16) -> Bool {
        // Caps Lock is a toggle and therefore cannot behave as a hold-to-record key.
        Int(keyCode) != kVK_CapsLock
    }

    static func displayName(for keyCode: UInt16, characters: String? = nil) -> String {
        switch Int(keyCode) {
        case kVK_Command: return "Left Command"
        case kVK_RightCommand: return "Right Command"
        case kVK_Shift: return "Left Shift"
        case kVK_RightShift: return "Right Shift"
        case kVK_Option: return "Left Option"
        case kVK_RightOption: return "Right Option"
        case kVK_Control: return "Left Control"
        case kVK_RightControl: return "Right Control"
        case kVK_Function: return "Fn (Globe)"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Forward Delete"
        case kVK_Escape: return "Escape"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_LeftArrow: return "Left Arrow"
        case kVK_RightArrow: return "Right Arrow"
        case kVK_UpArrow: return "Up Arrow"
        case kVK_DownArrow: return "Down Arrow"
        case kVK_Help: return "Help"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default:
            if let characters,
               let character = characters.first,
               !character.isWhitespace,
               !character.isNewline {
                return String(character).uppercased()
            }

            return "Key \(keyCode)"
        }
    }

    private static func legacyValue(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Function:
            return "fn"
        case kVK_RightOption:
            return "option"
        case kVK_RightControl:
            return "control"
        default:
            return "custom"
        }
    }
}

extension Notification.Name {
    static let hotkeyCaptureDidBegin = Notification.Name("hotkeyCaptureDidBegin")
    static let hotkeyCaptureDidEnd = Notification.Name("hotkeyCaptureDidEnd")
}
