//
//  HotkeyManager.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Carbon
import Cocoa

final class HotkeyManager {
    private var flagsMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var eventTapRunLoop: CFRunLoop?
    private var captureObservers: [NSObjectProtocol] = []
    private var isKeyDown = false
    private var isCapturingHotkey = false
    private var ignoredModifierReleaseKeyCode: UInt16?

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        observeHotkeyCapture()
        setupMonitor()
    }

    deinit {
        stopMonitoring()
        captureObservers.forEach(NotificationCenter.default.removeObserver)
    }

    private func setupMonitor() {
        logToFile("🎹 Setting up hotkey monitor for: \(HotkeyConfiguration.current.displayName)")

        // Try CGEvent tap first (more reliable for Fn key)
        if HotkeyManager.checkAccessibilityPermission(), setupCGEventMonitor() {
            logToFile("🎹 Using CGEvent tap (Accessibility granted)")
        } else {
            logToFile("🎹 Accessibility not granted, using NSEvent monitor (limited)")
            setupNSEventMonitors()
        }

        logToFile("🎹 Hotkey monitors initialized")
    }

    private func setupNSEventMonitors() {
        let eventTypes: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventTypes) { [weak self] event in
            _ = self?.handleNSEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventTypes) { [weak self] event in
            self?.handleNSEvent(event) == true ? nil : event
        }
    }

    private func handleNSEvent(_ event: NSEvent) -> Bool {
        guard !isCapturingHotkey else { return false }

        let configuration = HotkeyConfiguration.current
        guard event.keyCode == configuration.keyCode else { return false }

        if HotkeyConfiguration.isModifier(configuration.keyCode) {
            guard event.type == .flagsChanged else { return false }
            if ignoredModifierReleaseKeyCode == configuration.keyCode {
                ignoredModifierReleaseKeyCode = nil
                return true
            }
            updateKeyState(isPressed: !isKeyDown, source: "NSEvent")
            return true
        }

        switch event.type {
        case .keyDown:
            if !event.isARepeat {
                updateKeyState(isPressed: true, source: "NSEvent")
            }
        case .keyUp:
            updateKeyState(isPressed: false, source: "NSEvent")
        default:
            return false
        }

        return true
    }

    private func updateKeyState(isPressed: Bool, source: String) {
        guard isPressed != isKeyDown else { return }

        isKeyDown = isPressed
        logToFile("🎹 \(source): \(isPressed ? "Key DOWN" : "Key UP")")

        if isPressed {
            onKeyDown?()
        } else {
            onKeyUp?()
        }
    }

    private func observeHotkeyCapture() {
        let center = NotificationCenter.default
        let beginObserver = center.addObserver(
            forName: .hotkeyCaptureDidBegin,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setHotkeyCaptureActive(true)
        }
        let endObserver = center.addObserver(
            forName: .hotkeyCaptureDidEnd,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let capturedKeyCode = (notification.object as? NSNumber).flatMap {
                UInt16(exactly: $0.intValue)
            }
            self?.setHotkeyCaptureActive(false, capturedKeyCode: capturedKeyCode)
        }
        captureObservers = [beginObserver, endObserver]
    }

    private func setHotkeyCaptureActive(_ isActive: Bool, capturedKeyCode: UInt16? = nil) {
        if isActive, isKeyDown {
            updateKeyState(isPressed: false, source: "Hotkey capture")
        }
        if !isActive,
           let capturedKeyCode,
           HotkeyConfiguration.isModifier(capturedKeyCode) {
            ignoredModifierReleaseKeyCode = capturedKeyCode
        }
        isCapturingHotkey = isActive
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
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let eventTapRunLoopSource, let eventTapRunLoop {
            CFRunLoopRemoveSource(eventTapRunLoop, eventTapRunLoopSource, .commonModes)
            self.eventTapRunLoopSource = nil
            self.eventTapRunLoop = nil
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
    func setupCGEventMonitor() -> Bool {
        logToFile("🎹 Creating CGEvent tap...")
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                let shouldConsumeEvent = manager.handleCGEvent(event, type: type)
                return shouldConsumeEvent ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logToFile("❌ Failed to create CGEvent tap. Check accessibility permissions.")
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        eventTapRunLoopSource = runLoopSource
        eventTapRunLoop = runLoop
        logToFile("✅ CGEvent tap created and enabled")
        return true
    }

    private func handleCGEvent(_ event: CGEvent, type: CGEventType) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return false
        }

        guard !isCapturingHotkey else { return false }

        let configuration = HotkeyConfiguration.current
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == configuration.keyCode else { return false }

        if HotkeyConfiguration.isModifier(configuration.keyCode) {
            guard type == .flagsChanged else { return false }
            if ignoredModifierReleaseKeyCode == configuration.keyCode {
                ignoredModifierReleaseKeyCode = nil
                return true
            }
            updateKeyState(isPressed: !isKeyDown, source: "CGEvent")
            return true
        }

        switch type {
        case .keyDown:
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                updateKeyState(isPressed: true, source: "CGEvent")
            }
        case .keyUp:
            updateKeyState(isPressed: false, source: "CGEvent")
        default:
            return false
        }

        return true
    }
}
