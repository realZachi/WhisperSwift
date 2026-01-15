//
//  HotkeyManager.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import Carbon

class HotkeyManager {
    private var flagsMonitor: Any?
    private var localMonitor: Any?
    private var isKeyDown = false

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    // Selected hotkey from UserDefaults - default to "fn" for menu bar behavior
    private var selectedHotkey: String {
        UserDefaults.standard.string(forKey: "selectedHotkey") ?? "fn"
    }

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        setupMonitor()
    }

    deinit {
        stopMonitoring()
    }

    private func setupMonitor() {
        logToFile("🎹 Setting up hotkey monitor for: \(selectedHotkey)")

        // Try CGEvent tap first (more reliable for Fn key)
        if HotkeyManager.checkAccessibilityPermission() {
            logToFile("🎹 Using CGEvent tap (Accessibility granted)")
            setupCGEventMonitor()
        } else {
            logToFile("🎹 Accessibility not granted, using NSEvent monitor (limited)")
        }

        // Also add NSEvent monitors as backup
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Also add local monitor for when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        logToFile("🎹 Hotkey monitors initialized")
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let keyPressed: Bool
        let rawFlags = event.modifierFlags.rawValue

        switch selectedHotkey {
        case "fn":
            // Check for Function key (Globe key on newer Macs)
            keyPressed = event.modifierFlags.contains(.function)
        case "option":
            // Right Option key - check for option modifier
            // Note: NSEvent doesn't distinguish left/right option easily
            keyPressed = event.modifierFlags.contains(.option)
        case "control":
            // Right Control key
            keyPressed = event.modifierFlags.contains(.control)
        default:
            keyPressed = event.modifierFlags.contains(.function)
        }

        // Log raw flags for debugging
        if keyPressed != isKeyDown {
            logToFile("🎹 NSEvent flags: \(rawFlags), keyPressed: \(keyPressed), isKeyDown: \(isKeyDown)")
        }

        if keyPressed && !isKeyDown {
            // Key pressed down
            isKeyDown = true
            onKeyDown?()
        } else if !keyPressed && isKeyDown {
            // Key released
            isKeyDown = false
            onKeyUp?()
        }
    }

    func stopMonitoring() {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    /// Check if accessibility permissions are granted (required for global monitoring)
    static func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }
}

// MARK: - Alternative Key Detection using CGEvent (for more reliable detection)

extension HotkeyManager {
    /// Alternative setup using CGEvent tap for more reliable key detection
    /// This requires accessibility permissions
    func setupCGEventMonitor() {
        logToFile("🎹 Creating CGEvent tap...")
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handleCGEvent(event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logToFile("❌ Failed to create CGEvent tap. Check accessibility permissions.")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        logToFile("✅ CGEvent tap created and enabled")
    }

    private func handleCGEvent(_ event: CGEvent) {
        let flags = event.flags
        let rawFlags = flags.rawValue

        let keyPressed: Bool
        switch selectedHotkey {
        case "fn":
            keyPressed = flags.contains(.maskSecondaryFn)
        case "option":
            keyPressed = flags.contains(.maskAlternate)
        case "control":
            keyPressed = flags.contains(.maskControl)
        default:
            keyPressed = flags.contains(.maskSecondaryFn)
        }

        // Log for debugging
        if keyPressed != isKeyDown {
            logToFile("🎹 CGEvent flags: \(rawFlags), keyPressed: \(keyPressed), hotkey: \(selectedHotkey)")
        }

        if keyPressed && !isKeyDown {
            isKeyDown = true
            logToFile("⬇️ CGEvent: Key DOWN")
            DispatchQueue.main.async { [weak self] in
                self?.onKeyDown?()
            }
        } else if !keyPressed && isKeyDown {
            isKeyDown = false
            logToFile("⬆️ CGEvent: Key UP")
            DispatchQueue.main.async { [weak self] in
                self?.onKeyUp?()
            }
        }
    }
}
