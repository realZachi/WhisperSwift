//
//  TextInsertionService.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import Carbon

class TextInsertionService {

    /// Insert text into the currently focused text field using clipboard and Cmd+V
    func insertText(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general

        // Save current clipboard content
        let previousContents = pasteboard.string(forType: .string)

        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            // Simulate Cmd+V paste
            self?.simulatePaste()

            // Restore previous clipboard content after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let previous = previousContents {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }

    /// Simulate Cmd+V keyboard shortcut
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code for 'V' key
        let vKeyCode: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        // Create key down event with Command modifier
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            print("Failed to create key down event")
            return
        }
        keyDown.flags = .maskCommand

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("Failed to create key up event")
            return
        }
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Alternative: Insert text character by character (slower but more reliable in some apps)
    func insertTextCharByChar(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { continue }

            var chars = [UniChar](String(char).utf16)
            event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            event.post(tap: .cghidEventTap)

            // Key up
            guard let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }
            upEvent.post(tap: .cghidEventTap)

            // Small delay between characters
            usleep(1000) // 1ms
        }
    }
}

// MARK: - Accessibility-based Text Insertion (Alternative Method)

extension TextInsertionService {

    /// Try to insert text using Accessibility API directly
    /// This can work even when Cmd+V doesn't (e.g., in some terminal apps)
    func insertTextViaAccessibility(_ text: String) {
        guard let focusedElement = getFocusedElement() else {
            // Fall back to clipboard method
            insertText(text)
            return
        }

        // Try to set the value directly
        var textValue: CFTypeRef = text as CFTypeRef
        let result = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, textValue)

        if result != .success {
            // If direct setting fails, try inserting at cursor position
            if let currentValue = getAttributeValue(focusedElement, attribute: kAXValueAttribute) as? String {
                // Get selected range
                if let selectedRange = getAttributeValue(focusedElement, attribute: kAXSelectedTextRangeAttribute) {
                    // Insert at cursor - fall back to paste method
                    insertText(text)
                }
            } else {
                // Fall back to paste method
                insertText(text)
            }
        }
    }

    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let appElement = focusedApp else {
            return nil
        }

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        return focusedElement as! AXUIElement?
    }

    private func getAttributeValue(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }
}
