//
//  HotkeyManager.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import Carbon

class HotkeyManager {
    private var flagsMonitor: Any?
    private var isKeyDown = false

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    // Selected hotkey from settings
    @AppStorage("selectedHotkey") private var selectedHotkey = "fn"

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        setupMonitor()
    }

    deinit {
        stopMonitoring()
    }

    private func setupMonitor() {
        // Monitor for modifier key changes (Fn, Option, Control)
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Also add local monitor for when app is focused
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        print("Hotkey monitor initialized for: \(selectedHotkey)")
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let keyPressed: Bool

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
    }

    /// Check if accessibility permissions are granted (required for global monitoring)
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permission with prompt
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Alternative Key Detection using CGEvent (for more reliable detection)

extension HotkeyManager {
    /// Alternative setup using CGEvent tap for more reliable key detection
    /// This requires accessibility permissions
    func setupCGEventMonitor() {
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
            print("Failed to create CGEvent tap. Check accessibility permissions.")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleCGEvent(_ event: CGEvent) {
        let flags = event.flags

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

        if keyPressed && !isKeyDown {
            isKeyDown = true
            DispatchQueue.main.async { [weak self] in
                self?.onKeyDown?()
            }
        } else if !keyPressed && isKeyDown {
            isKeyDown = false
            DispatchQueue.main.async { [weak self] in
                self?.onKeyUp?()
            }
        }
    }
}
