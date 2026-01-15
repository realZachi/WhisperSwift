//
//  AppDelegate.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import SwiftUI

func logToFile(_ message: String) {
    let logFile = "/tmp/localwhisper.log"
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let logMessage = "[\(timestamp)] \(message)\n"
    if let handle = FileHandle(forWritingAtPath: logFile) {
        handle.seekToEndOfFile()
        handle.write(logMessage.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: logFile, contents: logMessage.data(using: .utf8), attributes: nil)
    }
    print(message) // Also print to stdout
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager?
    private var groqService: GroqTranscriptionService?
    private var audioRecorder: AudioRecorder?
    private var textInsertionService: TextInsertionService?
    private var recordingPillController: RecordingPillController?
    private var contextService: ContextService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logToFile("🚀 App started")
        UserDefaults.standard.register(defaults: [
            "selectedHotkey": "fn",
            "playSounds": true,
            "groqModel": "whisper-large-v3-turbo",
            "groqLanguage": "de"
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
                Task { await self?.startRecording() }
            },
            onKeyUp: { [weak self] in
                logToFile("⬆️ Key UP detected")
                Task { await self?.stopRecordingAndTranscribe() }
            }
        )

        logToFile("✅ LocalWhisper initialized successfully")
    }

    private func startRecording() async {
        guard let audioRecorder = audioRecorder else {
            logToFile("❌ audioRecorder is nil")
            return
        }

        await MainActor.run {
            statusBarController?.state = .recording
            recordingPillController?.show()
        }

        do {
            try await audioRecorder.startRecording()
            logToFile("🎤 Recording started")
        } catch {
            logToFile("❌ Failed to start recording: \(error)")
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

        await MainActor.run {
            statusBarController?.state = .processing
            recordingPillController?.transitionToProcessing()
        }

        // Stop recording and get audio samples
        logToFile("⏹️ Stopping recording...")
        let recording = await audioRecorder.stopRecording()

        guard !recording.samples.isEmpty else {
            logToFile("❌ No audio recorded (0 samples)")
            await MainActor.run {
                statusBarController?.state = .idle
                recordingPillController?.hide()
            }
            return
        }

        logToFile("📊 Recorded \(recording.samples.count) samples, transcribing...")

        // Transcribe audio
        do {
            let transcription = try await groqService.transcribe(recording: recording)

            if !transcription.isEmpty {
                logToFile("✅ Transcription: \(transcription)")

                // Insert text into focused application
                await MainActor.run {
                    let snapshot = contextService?.captureSnapshot()
                    if let snapshot {
                        logToFile("🧠 Context app=\(snapshot.appName ?? "unknown") title=\(snapshot.windowTitle ?? "none") doc=\(snapshot.documentName ?? "none")")
                        let candidates = contextService?.candidateFilenames(snapshot: snapshot) ?? []
                        if !candidates.isEmpty {
                            logToFile("🧠 Context candidates: \(candidates.joined(separator: ", "))")
                        }
                    }

                    let contextualized = contextService?.applyContext(to: transcription, snapshot: snapshot) ?? transcription
                    if contextualized != transcription {
                        logToFile("🧠 Contextualized transcription: \(contextualized)")
                    }

                    logToFile("📝 Inserting text...")
                    let outcome = textInsertionService.insertText(contextualized)
                    switch outcome {
                    case .inserted:
                        logToFile("✅ Text inserted")
                    case .copiedToClipboard:
                        logToFile("📋 Text copied to clipboard (enable Accessibility for auto-insert)")
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

        await MainActor.run {
            statusBarController?.state = .idle
            recordingPillController?.hide()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager = nil
        audioRecorder = nil
        groqService = nil
    }
}
