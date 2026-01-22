//
//  AppDelegate.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import UserNotifications
import Carbon

/// Scrubs sensitive data from log messages before writing to disk.
/// Redacts API keys, tokens, and other potentially sensitive patterns.
private func scrubSensitiveData(_ message: String) -> String {
    var scrubbed = message

    // Redact API keys (common formats: gsk_*, sk-*, key-*, etc.)
    let apiKeyPatterns = [
        "(gsk_)[A-Za-z0-9]{20,}",           // Groq API keys
        "(sk-)[A-Za-z0-9]{20,}",            // OpenAI-style keys
        "(key-)[A-Za-z0-9]{20,}",           // Generic API keys
        "(api[_-]?key[=:]\\s*)[A-Za-z0-9]{16,}", // api_key=xxx or apiKey: xxx
        "(token[=:]\\s*)[A-Za-z0-9]{16,}",  // token=xxx
        "(bearer\\s+)[A-Za-z0-9._-]{20,}",  // Bearer tokens
    ]

    for pattern in apiKeyPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(scrubbed.startIndex..., in: scrubbed)
            scrubbed = regex.stringByReplacingMatches(
                in: scrubbed,
                options: [],
                range: range,
                withTemplate: "$1[REDACTED]"
            )
        }
    }

    // Redact email addresses
    if let emailRegex = try? NSRegularExpression(
        pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
        options: .caseInsensitive
    ) {
        let range = NSRange(scrubbed.startIndex..., in: scrubbed)
        scrubbed = emailRegex.stringByReplacingMatches(
            in: scrubbed,
            options: [],
            range: range,
            withTemplate: "[EMAIL_REDACTED]"
        )
    }

    return scrubbed
}

nonisolated func logToFile(_ message: String) {
    let logFile = "/tmp/whisperswift.log"
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let scrubbedMessage = scrubSensitiveData(message)
    let logMessage = "[\(timestamp)] \(scrubbedMessage)\n"
    guard let data = logMessage.data(using: .utf8) else { return }
    if let handle = FileHandle(forWritingAtPath: logFile) {
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: logFile, contents: data, attributes: nil)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private enum RecordingGestureConstants {
        static let tapMaxDuration: TimeInterval = 0.35
        static let doubleTapInterval: TimeInterval = 0.50
    }

    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager?
    private var manualPasteMonitor: Any?
    private var groqService: GroqTranscriptionService?
    private var audioRecorder: AudioRecorder?
    private var textInsertionService: TextInsertionService?
    private var recordingPillController: RecordingPillController?
    private var contextService: ContextService?
    private var textCleanupContextResolver: TextCleanupContextResolver?
    private var isRecording = false
    private var isProcessing = false
    private var isLockedRecording = false
    private var keyDownTimestamp: TimeInterval?
    private var lastTapEndTimestamp: TimeInterval?
    private var pendingStopWorkItem: DispatchWorkItem?
    private var lastTranscription: String?
    private var transcriptionExpiryWorkItem: DispatchWorkItem?
    private var pillHideWorkItem: DispatchWorkItem?
    private var manualPasteEventTap: CFMachPort?
    private var manualPasteRunLoopSource: CFRunLoopSource?
    private var manualPasteLocalMonitor: Any?
    private var lastManualPasteTrigger: TimeInterval?

    private enum ManualPasteConstants {
        static let pillDisplayInterval: TimeInterval = 3.0
        static let retentionInterval: TimeInterval = 10.0
        static let debounceInterval: TimeInterval = 0.3
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logToFile("🚀 App started")
        UserDefaults.standard.register(defaults: [
            "selectedHotkey": "fn",
            "playSounds": true,
            "groqModel": "whisper-large-v3-turbo",
        ])

        // Initialize status bar
        statusBarController = StatusBarController()

        // Initialize services
        Task {
            await initializeServices()
        }
    }

    private func initializeServices() async {
        logToFile("🔧 initializeServices started")

        // Check and request permissions
        logToFile("🔐 Requesting permissions...")
        await PermissionManager.shared.requestPermissions()
        logToFile("🔐 Permissions done")

        // Initialize text insertion service
        logToFile("📝 Creating TextInsertionService...")
        textInsertionService = TextInsertionService()

        // Initialize context service
        logToFile("🧠 Creating ContextService...")
        contextService = ContextService()

        // Initialize text cleanup context resolver
        logToFile("🧾 Creating TextCleanupContextResolver...")
        textCleanupContextResolver = TextCleanupContextResolver()

        // Initialize recording pill overlay
        logToFile("💊 Creating RecordingPillController...")
        recordingPillController = RecordingPillController()

        // Initialize audio recorder
        logToFile("🎤 Creating AudioRecorder...")
        audioRecorder = AudioRecorder()

        // Connect audio level callback to pill
        if let pillController = recordingPillController {
            await audioRecorder?.setLevelCallback { level in
                pillController.updateLevel(level)
            }
        }

        // Initialize Groq transcription service
        logToFile("🤖 Initializing Groq transcription service...")
        groqService = GroqTranscriptionService()
        logToFile("✅ Groq transcription service initialized")

        // Initialize hotkey manager
        logToFile("🎹 Setting up hotkey manager...")
        hotkeyManager = HotkeyManager(
            onKeyDown: { [weak self] in
                logToFile("⬇️ Key DOWN detected")
                Task { await self?.handleHotkeyDown() }
            },
            onKeyUp: { [weak self] in
                logToFile("⬆️ Key UP detected")
                Task { await self?.handleHotkeyUp() }
            }
        )

        // Setup manual paste hotkey (Cmd+Ctrl+V)
        setupManualPasteHotkey()

        logToFile("✅ whisperswift initialized successfully")
    }

    private func setupManualPasteHotkey() {
        setupManualPasteEventTap()

        // Global monitor for Cmd+Ctrl+V
        manualPasteMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Cmd+Ctrl+V (keyCode 9 = V)
            if event.keyCode == 9 &&
               event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.control) {
                Task { @MainActor in
                    self?.handleManualPasteIfNeeded()
                }
            }
        }

        // Also add local monitor for when app window is focused
        manualPasteLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 9 &&
               event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.control) {
                Task { @MainActor in
                    self?.handleManualPasteIfNeeded()
                }
                return nil // Consume the event
            }
            return event
        }

        logToFile("🎹 Manual paste hotkey (⌘⌃V) registered")
    }

    private func setupManualPasteEventTap() {
        guard manualPasteEventTap == nil else { return }
        guard AXIsProcessTrusted() else {
            logToFile("⚠️ Accessibility not granted - CGEvent tap for manual paste unavailable")
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                manager.handleManualPasteEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logToFile("❌ Failed to create CGEvent tap for manual paste")
            return
        }

        manualPasteEventTap = eventTap
        manualPasteRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let source = manualPasteRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        logToFile("✅ CGEvent tap for manual paste enabled")
    }

    nonisolated private func handleManualPasteEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(kVK_ANSI_V) else { return }
        guard event.flags.contains(.maskCommand) && event.flags.contains(.maskControl) else { return }
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        guard !isRepeat else { return }

        DispatchQueue.main.async { [weak self] in
            self?.handleManualPasteIfNeeded()
        }
    }

    private func handleManualPasteIfNeeded() {
        let now = Date.timeIntervalSinceReferenceDate
        if let last = lastManualPasteTrigger, now - last < ManualPasteConstants.debounceInterval {
            return
        }
        lastManualPasteTrigger = now
        handleManualPaste()
    }

    private func handleManualPaste() {
        guard let textInsertionService = textInsertionService,
              let lastText = lastTranscription else {
            logToFile("⚠️ No transcription available for manual paste")
            return
        }

        logToFile("📋 Manual paste triggered for: \(lastText.prefix(50))...")

        // Hide the pill if it's showing
        transcriptionExpiryWorkItem?.cancel()
        pillHideWorkItem?.cancel()
        recordingPillController?.hide()

        // Try to insert the saved transcription
        let outcome = textInsertionService.insertText(lastText)
        switch outcome {
        case .inserted:
            logToFile("✅ Manual paste successful")
            lastTranscription = nil // Clear after successful paste
            transcriptionExpiryWorkItem?.cancel()
            transcriptionExpiryWorkItem = nil
        case .noFocusedTarget:
            logToFile("⚠️ Still no focused target for manual paste")
        case .copiedToClipboard:
            logToFile("📋 Text still in clipboard")
        case .empty:
            logToFile("⚠️ Empty transcription")
        }
    }

    private func showSavedNotification(text: String) {
        // Transition pill to saved state
        recordingPillController?.transitionToSaved(text: text)
        statusBarController?.state = .idle
        isProcessing = false

        schedulePillAutoHide()
        scheduleTranscriptionExpiry(hidePill: false)
    }

    private func schedulePillAutoHide() {
        pillHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isRecording && !self.isProcessing else { return }
            self.recordingPillController?.hide()
        }
        pillHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ManualPasteConstants.pillDisplayInterval,
            execute: workItem
        )
    }

    private func scheduleTranscriptionExpiry(hidePill: Bool) {
        transcriptionExpiryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if hidePill && !self.isRecording && !self.isProcessing {
                self.recordingPillController?.hide()
            }
            self.lastTranscription = nil
        }
        transcriptionExpiryWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ManualPasteConstants.retentionInterval,
            execute: workItem
        )
    }

    private func handleHotkeyDown() async {
        if isProcessing {
            logToFile("⏳ Ignoring hotkey while processing")
            return
        }

        if isLockedRecording {
            await stopRecordingAndTranscribe()
            return
        }

        // Check for API key before starting recording
        if let groqService = groqService, !groqService.hasApiKey() {
            logToFile("⚠️ API key missing, showing notification")
            await showApiKeyMissingAlert()
            return
        }

        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil

        keyDownTimestamp = Date.timeIntervalSinceReferenceDate

        if !isRecording {
            await startRecording()
        }
    }

    private func showApiKeyMissingAlert() async {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "API Key Missing"
            alert.informativeText = "Please enter your Groq API key in Settings to use speech recognition."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")

            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                statusBarController?.openSettings()
            }
        }
    }

    private func handleHotkeyUp() async {
        guard !isLockedRecording else {
            logToFile("⬆️ Key up ignored - hands-free lock active")
            return
        }
        guard isRecording else {
            logToFile("⬆️ Key up ignored - not currently recording")
            return
        }

        let now = Date.timeIntervalSinceReferenceDate

        guard let downTimestamp = keyDownTimestamp else {
            logToFile("⚠️ Key up received without corresponding key down timestamp - stopping recording")
            lastTapEndTimestamp = nil
            await stopRecordingAndTranscribe()
            return
        }

        let pressDuration = now - downTimestamp
        keyDownTimestamp = nil

        if pressDuration <= RecordingGestureConstants.tapMaxDuration {
            if let lastTapEndTimestamp,
               now - lastTapEndTimestamp <= RecordingGestureConstants.doubleTapInterval {
                self.lastTapEndTimestamp = nil
                isLockedRecording = true
                logToFile("🔒 Hands-free lock engaged (double-tap)")
                return
            }

            lastTapEndTimestamp = now
            scheduleStopAfterDoubleTapWindow()
        } else {
            lastTapEndTimestamp = nil
            pendingStopWorkItem?.cancel()
            pendingStopWorkItem = nil
            await stopRecordingAndTranscribe()
        }
    }

    private func scheduleStopAfterDoubleTapWindow() {
        guard isRecording else { return }

        pendingStopWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard self.isRecording && !self.isLockedRecording && !self.isProcessing else {
                    logToFile("⏱️ Scheduled stop skipped - state changed (recording=\(self.isRecording), locked=\(self.isLockedRecording), processing=\(self.isProcessing))")
                    return
                }
                logToFile("⏱️ Double-tap window expired, stopping recording")
                await self.stopRecordingAndTranscribe()
            }
        }
        pendingStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + RecordingGestureConstants.doubleTapInterval,
            execute: workItem
        )
    }

    private func startRecording() async {
        guard let audioRecorder = audioRecorder else {
            logToFile("❌ audioRecorder is nil")
            return
        }

        guard !isRecording && !isProcessing else {
            logToFile("⚠️ Ignoring start request; already recording or processing")
            return
        }

        isRecording = true
        isLockedRecording = false

        await MainActor.run {
            statusBarController?.state = .recording
            recordingPillController?.show()
        }

        do {
            try await audioRecorder.startRecording()
            logToFile("🎤 Recording started")
        } catch {
            logToFile("❌ Failed to start recording: \(error)")
            isRecording = false
            isLockedRecording = false
            keyDownTimestamp = nil
            lastTapEndTimestamp = nil
            pendingStopWorkItem?.cancel()
            pendingStopWorkItem = nil
            await MainActor.run {
                statusBarController?.state = .idle
                recordingPillController?.hide()
            }
        }
    }

    private func stopRecordingAndTranscribe() async {
        guard let audioRecorder = audioRecorder,
              let groqService = groqService,
              let textInsertionService = textInsertionService else {
            logToFile("❌ Services not initialized")
            return
        }

        guard isRecording else {
            logToFile("⚠️ Ignoring stop request; not currently recording")
            return
        }

        isRecording = false
        isProcessing = true
        isLockedRecording = false
        keyDownTimestamp = nil
        lastTapEndTimestamp = nil
        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil

        await MainActor.run {
            statusBarController?.state = .processing
            recordingPillController?.transitionToProcessing()
        }

        // Stop recording and get audio samples
        logToFile("⏹️ Stopping recording...")
        let recording = await audioRecorder.stopRecording()

        guard !recording.samples.isEmpty else {
            logToFile("❌ No audio recorded (0 samples)")
            isProcessing = false
            await MainActor.run {
                statusBarController?.state = .idle
                recordingPillController?.hide()
            }
            return
        }

        logToFile("📊 Recorded \(recording.samples.count) samples, transcribing...")

        // Transcribe audio
        var shouldKeepPillVisible = false

        do {
            let transcription = try await groqService.transcribe(recording: recording)

            if !transcription.isEmpty {
                logToFile("✅ Transcription: \(transcription)")

                let snapshot = contextService?.captureSnapshot()
                let profile = textCleanupContextResolver?.resolveProfile(snapshot: snapshot) ?? .default

                if let snapshot {
                    logToFile("🧾 Cleanup profile=\(profile.rawValue) bundleId=\(snapshot.bundleId ?? "unknown") app=\(snapshot.appName ?? "unknown")")
                } else {
                    logToFile("🧾 Cleanup profile=\(profile.rawValue) (no context snapshot)")
                }

                let cleaned: String
                do {
                    cleaned = try await groqService.cleanTranscription(transcription, profile: profile)
                    if cleaned.isEmpty {
                        logToFile("⏭️ Cleanup returned empty")
                    } else if cleaned != transcription {
                        logToFile("✅ Cleaned transcription: \(cleaned)")
                    }
                } catch {
                    logToFile("⚠️ Cleanup failed, using raw transcription: \(error)")
                    cleaned = transcription
                }

                // Insert text into focused application
                await MainActor.run {
                    if let snapshot {
                        logToFile("🧠 Context app=\(snapshot.appName ?? "unknown") title=\(snapshot.windowTitle ?? "none") doc=\(snapshot.documentName ?? "none")")
                        let candidates = contextService?.candidateFilenames(snapshot: snapshot) ?? []
                        if !candidates.isEmpty {
                            logToFile("🧠 Context candidates: \(candidates.joined(separator: ", "))")
                        }
                    }

                    let contextualized = contextService?.applyContext(to: cleaned, snapshot: snapshot) ?? cleaned
                    if contextualized != cleaned {
                        logToFile("🧠 Contextualized transcription: \(contextualized)")
                    }

                    logToFile("📝 Inserting text...")
                    let outcome = textInsertionService.insertText(contextualized)
                    switch outcome {
                    case .inserted:
                        logToFile("✅ Text inserted")
                        self.lastTranscription = nil
                    case .copiedToClipboard:
                        logToFile("📋 Text copied to clipboard (enable Accessibility for auto-insert)")
                        self.lastTranscription = contextualized
                        self.scheduleTranscriptionExpiry(hidePill: false)
                    case .noFocusedTarget:
                        logToFile("📋 No focused target - saved to clipboard, showing notification")
                        self.lastTranscription = contextualized
                        self.showSavedNotification(text: contextualized)
                        shouldKeepPillVisible = true
                    case .empty:
                        logToFile("⚠️ Empty transcription result")
                    }
                }
            } else {
                logToFile("⚠️ Empty transcription result")
            }
        } catch GroqTranscriptionError.missingApiKey {
            logToFile("⚠️ Groq API key missing. Set it in Settings or via GROQ_API_KEY.")
        } catch {
            logToFile("❌ Transcription failed: \(error)")
        }

        if shouldKeepPillVisible {
            return
        }

        await MainActor.run {
            statusBarController?.state = .idle
            recordingPillController?.hide()
        }

        isProcessing = false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = manualPasteMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = manualPasteLocalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let eventTap = manualPasteEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let source = manualPasteRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        hotkeyManager = nil
        audioRecorder = nil
        groqService = nil
    }
}
