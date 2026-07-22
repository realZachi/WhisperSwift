//
//  HotkeyRecorderView.swift
//  whisperswift
//

import AppKit
import SwiftUI

struct HotkeyRecorderView: View {
    @State private var isCapturing = false
    @State private var validationMessage: String?
    @AppStorage(HotkeyConfiguration.keyCodeDefaultsKey) private var storedKeyCode = -1
    @AppStorage(HotkeyConfiguration.displayNameDefaultsKey) private var storedDisplayName = ""

    private var displayName: String {
        guard storedKeyCode >= 0,
              let keyCode = UInt16(exactly: storedKeyCode) else {
            return HotkeyConfiguration.current.displayName
        }

        return storedDisplayName.isEmpty
            ? HotkeyConfiguration.displayName(for: keyCode)
            : storedDisplayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                if isCapturing {
                    stopCapturing()
                } else {
                    validationMessage = nil
                    isCapturing = true
                    NotificationCenter.default.post(name: .hotkeyCaptureDidBegin, object: nil)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCapturing ? "keyboard.badge.ellipsis" : "keyboard")
                    Text(isCapturing ? "Press any key…" : displayName)
                }
                .frame(minWidth: 145)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Push-to-Talk key")
            .accessibilityValue(isCapturing ? "Waiting for a key" : displayName)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            KeyCaptureView(
                isActive: isCapturing,
                onKeyCaptured: capture,
                onCaptureCancelled: stopCapturing
            )
            .frame(width: 1, height: 1)
            .opacity(0)
        }
        .onDisappear {
            stopCapturing()
        }
    }

    private func capture(_ event: NSEvent) {
        guard HotkeyConfiguration.isSupported(event.keyCode) else {
            validationMessage = "Caps Lock cannot be used for hold-to-record. Press another key."
            return
        }

        let name = HotkeyConfiguration.displayName(
            for: event.keyCode,
            characters: event.charactersIgnoringModifiers
        )
        HotkeyConfiguration.save(keyCode: event.keyCode, displayName: name)
        storedKeyCode = Int(event.keyCode)
        storedDisplayName = name
        validationMessage = nil
        isCapturing = false
        NotificationCenter.default.post(
            name: .hotkeyCaptureDidEnd,
            object: NSNumber(value: event.keyCode)
        )
    }

    private func stopCapturing() {
        guard isCapturing else { return }
        isCapturing = false
        NotificationCenter.default.post(name: .hotkeyCaptureDidEnd, object: nil)
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    let isActive: Bool
    let onKeyCaptured: (NSEvent) -> Void
    let onCaptureCancelled: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyCaptured = onKeyCaptured
        view.onCaptureCancelled = onCaptureCancelled
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKeyCaptured = onKeyCaptured
        nsView.onCaptureCancelled = onCaptureCancelled
        nsView.isActive = isActive

        if isActive {
            DispatchQueue.main.async { [weak nsView] in
                guard let nsView, let window = nsView.window else { return }
                window.makeFirstResponder(nsView)
            }
        } else if nsView.window?.firstResponder === nsView {
            nsView.window?.makeFirstResponder(nil)
        }
    }
}

private final class KeyCaptureNSView: NSView {
    var onKeyCaptured: ((NSEvent) -> Void)?
    var onCaptureCancelled: (() -> Void)?
    var isActive = false {
        didSet {
            updateEventMonitor()
        }
    }

    private var eventMonitor: Any?

    deinit {
        removeEventMonitor()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        _ = captureIfNeeded(event)
    }

    override func flagsChanged(with event: NSEvent) {
        _ = captureIfNeeded(event)
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign, isActive {
            DispatchQueue.main.async { [weak self] in
                self?.onCaptureCancelled?()
            }
        }
        return didResign
    }

    private func updateEventMonitor() {
        guard isActive else {
            removeEventMonitor()
            return
        }
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            guard let self, self.isActive else { return event }
            return self.captureIfNeeded(event) ? nil : event
        }
    }

    private func removeEventMonitor() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func captureIfNeeded(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            guard !event.isARepeat else { return false }
        case .flagsChanged:
            if HotkeyConfiguration.isModifier(event.keyCode) {
                guard HotkeyConfiguration.isModifierPressed(
                    event.keyCode,
                    in: event.modifierFlags
                ) else {
                    return false
                }
            } else {
                guard !HotkeyConfiguration.isSupported(event.keyCode) else {
                    return false
                }
            }
        default:
            return false
        }

        onKeyCaptured?(event)
        return true
    }
}
