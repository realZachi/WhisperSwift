//
//  TextInsertionService.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import Carbon

class TextInsertionService {
    enum InsertionOutcome {
        case inserted
        case copiedToClipboard
        case noFocusedTarget
        case empty
    }

    private enum Constants {
        static let pasteboardSettleDelay: TimeInterval = 0.05
        static let pasteboardRestoreDelay: TimeInterval = 0.1
    }

    private let accessibilityInsertPromptKey = "didPromptAccessibilityInsert"
    private let accessibilityInsertBlacklist: Set<String> = [
        // Code editors (handle text insertion differently)
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.vscodium",
        // Browsers (web textboxes don't support Accessibility API text insertion)
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser", // Arc
    ]

    /// Insert text into the currently focused text field using Accessibility or clipboard.
    @discardableResult
    func insertText(_ text: String) -> InsertionOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let frontmostBundleId = frontmostBundleIdentifier()
        logToFile("📝 Insert target bundle id: \(frontmostBundleId ?? "unknown")")

        guard AXIsProcessTrusted() else {
            copyToClipboard(trimmed)
            promptAccessibilityIfNeeded()
            logToFile("⚠️ Accessibility not granted - copied transcription to clipboard")
            return .copiedToClipboard
        }

        // Check if there's a focused text element
        let hasFocused = hasFocusedTextElement()

        if !hasFocused {
            // No focused element found via Accessibility API
            // But if there's a frontmost app, still try clipboard paste - it often works
            // even when Accessibility can't find the focused element (e.g., Electron apps)
            if frontmostBundleId != nil {
                logToFile("⚠️ No focused element via Accessibility, but app is frontmost - trying clipboard paste")
                pasteViaClipboard(trimmed)
                return .inserted
            } else {
                copyToClipboard(trimmed)
                logToFile("⚠️ No focused text element and no frontmost app - saved to clipboard")
                return .noFocusedTarget
            }
        }

        if let bundleId = frontmostBundleId, accessibilityInsertBlacklist.contains(bundleId) {
            logToFile("⚠️ Skipping Accessibility insert for bundle id: \(bundleId)")
        } else if insertTextViaAccessibility(trimmed) {
            logToFile("✅ Inserted via Accessibility API")
            return .inserted
        } else {
            logToFile("⚠️ Accessibility insert failed, falling back to clipboard paste")
        }

        pasteViaClipboard(trimmed)
        return .inserted
    }

    private func pasteViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard content
        let previousContents = pasteboard.string(forType: .string)
        logToFile("📋 Clipboard paste start (saved existing clipboard: \(previousContents != nil))")

        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.pasteboardSettleDelay) { [weak self] in
            // Simulate Cmd+V paste
            logToFile("⌨️ Simulating Cmd+V")
            self?.simulatePaste()

            // Restore previous clipboard content after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.pasteboardRestoreDelay) {
                if let previous = previousContents {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                    logToFile("📋 Clipboard restored to previous content")
                } else {
                    logToFile("📋 Clipboard left as inserted text (no previous content)")
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Simulate Cmd+V keyboard shortcut
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code for 'V' key
        let vKeyCode: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        // Create key down event with Command modifier
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            logToFile("❌ Failed to create key down event")
            return
        }
        keyDown.flags = .maskCommand

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            logToFile("❌ Failed to create key up event")
            return
        }
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func promptAccessibilityIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: accessibilityInsertPromptKey) else { return }
        UserDefaults.standard.set(true, forKey: accessibilityInsertPromptKey)
        DispatchQueue.main.async {
            _ = PermissionManager.shared.requestAccessibilityAccess()
        }
    }

    private func frontmostBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    /// Check if there's a focused element that could potentially receive text.
    /// We use a permissive approach: if ANY element is focused, we try to paste.
    /// The clipboard paste fallback (Cmd+V) works in virtually all apps.
    private func hasFocusedTextElement() -> Bool {
        guard let focused = getFocusedElement() else {
            logToFile("🔍 hasFocusedTextElement: getFocusedElement() returned nil")
            return false
        }

        // Get the role of the focused element
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &role)
        guard roleResult == .success, let roleString = role as? String else {
            // If we can't get the role, still try to paste - worst case it doesn't work
            logToFile("🔍 hasFocusedTextElement: Can't get role (error: \(roleResult.rawValue)), trying paste anyway")
            return true
        }

        logToFile("🔍 hasFocusedTextElement: Focused element role = \(roleString)")

        // Roles that definitely DON'T accept text input
        let nonTextRoles: Set<String> = [
            kAXMenuBarRole as String,
            kAXMenuRole as String,
            kAXMenuItemRole as String,
            kAXToolbarRole as String,
            "AXScrollBar",
            "AXSplitter",
        ]

        // If it's definitely not a text-accepting element, don't try
        if nonTextRoles.contains(roleString) {
            logToFile("🔍 hasFocusedTextElement: Role is in nonTextRoles, returning false")
            return false
        }

        // For all other roles (including unknown ones), try to paste
        // This covers: text fields, text areas, web areas, code editors, terminals, etc.
        logToFile("🔍 hasFocusedTextElement: Role accepted, returning true")
        return true
    }

}

// MARK: - Accessibility-based Text Insertion (Alternative Method)

extension TextInsertionService {

    /// Try to insert text using Accessibility API directly
    /// This can work even when Cmd+V doesn't (e.g., in some terminal apps)
    private func insertTextViaAccessibility(_ text: String) -> Bool {
        guard let focusedElement = getFocusedElement() else {
            logToFile("⚠️ Accessibility: No focused element found")
            return false
        }

        // Use kAXSelectedTextAttribute to insert at cursor position
        // This replaces the current selection (or inserts if nothing selected)
        let textValue: CFTypeRef = text as CFTypeRef
        let result = AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, textValue)

        if result == .success {
            logToFile("✅ Accessibility: Inserted via kAXSelectedTextAttribute")
            return true
        }

        // Fallback: Try kAXValueAttribute only if the element doesn't support selected text
        // (e.g., some non-standard text fields)
        logToFile("⚠️ Accessibility: kAXSelectedTextAttribute failed (\(result.rawValue)), trying kAXValueAttribute fallback")

        // Get current value and selection range to manually insert
        if let currentValue = getAttributeValue(focusedElement, attribute: kAXValueAttribute as String) as? String,
           let rangeValue = getAttributeValue(focusedElement, attribute: kAXSelectedTextRangeAttribute as String) {

            var range = CFRange()
            guard CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
                logToFile("⚠️ Accessibility: selected range value is not AXValue")
                return false
            }
            let axRangeValue = unsafeBitCast(rangeValue, to: AXValue.self)
            if AXValueGetValue(axRangeValue, .cfRange, &range) {
                // Build new string with text inserted at cursor position
                let startIndex = currentValue.index(currentValue.startIndex, offsetBy: min(range.location, currentValue.count))
                let endIndex = currentValue.index(startIndex, offsetBy: min(range.length, currentValue.count - range.location))

                var newValue = currentValue
                newValue.replaceSubrange(startIndex..<endIndex, with: text)

                let newTextValue: CFTypeRef = newValue as CFTypeRef
                let fallbackResult = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, newTextValue)

                if fallbackResult == .success {
                    // Move cursor to end of inserted text
                    let newCursorPos = range.location + text.count
                    var newRangeValue = CFRange(location: newCursorPos, length: 0)
                    if let newRange = AXValueCreate(.cfRange, &newRangeValue) {
                        AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, newRange)
                    }
                    logToFile("✅ Accessibility: Inserted via kAXValueAttribute with manual cursor handling")
                    return true
                }
            }
        }

        logToFile("❌ Accessibility: All insertion methods failed")
        return false
    }

    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let focusedApp,
              CFGetTypeID(focusedApp) == AXUIElementGetTypeID() else {
            return nil
        }
        let appElement = unsafeBitCast(focusedApp, to: AXUIElement.self)

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let focusedElement,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeBitCast(focusedElement, to: AXUIElement.self)
    }

    private func getAttributeValue(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }
}
