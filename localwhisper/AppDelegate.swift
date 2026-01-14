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
    private var whisperService: WhisperService?
    private var audioRecorder: AudioRecorder?
    private var textInsertionService: TextInsertionService?
    private var recordingPillController: RecordingPillController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logToFile("🚀 App started")
        UserDefaults.standard.register(defaults: [
            "selectedHotkey": "fn",
            "playSounds": true
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

        // Initialize Whisper service (loads model)
        logToFile("🤖 Loading Whisper model...")
        do {
            whisperService = try await WhisperService()
            logToFile("✅ Whisper model loaded successfully")
        } catch {
            logToFile("❌ Failed to load Whisper model: \(error)")
            await showModelLoadError(error)
        }

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
              let whisperService = whisperService,
              let textInsertionService = textInsertionService else {
            logToFile("❌ Services not initialized")
            return
        }

        await MainActor.run {
            statusBarController?.state = .processing
            recordingPillController?.hide()
        }

        // Stop recording and get audio samples
        logToFile("⏹️ Stopping recording...")
        let audioSamples = await audioRecorder.stopRecording()

        guard !audioSamples.isEmpty else {
            logToFile("❌ No audio recorded (0 samples)")
            await MainActor.run {
                statusBarController?.state = .idle
            }
            return
        }

        logToFile("📊 Recorded \(audioSamples.count) samples, transcribing...")

        // Transcribe audio
        do {
            let transcription = try await whisperService.transcribe(audioSamples: audioSamples)

            if !transcription.isEmpty {
                logToFile("✅ Transcription: \(transcription)")

                // Insert text into focused application
                await MainActor.run {
                    logToFile("📝 Inserting text...")
                    textInsertionService.insertText(transcription)
                    logToFile("✅ Text inserted")
                }
            } else {
                logToFile("⚠️ Empty transcription result")
            }
        } catch {
            logToFile("❌ Transcription failed: \(error)")
        }

        await MainActor.run {
            statusBarController?.state = .idle
        }
    }

    private func showModelLoadError(_ error: Error) async {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Failed to Load Whisper Model"
            alert.informativeText = "The speech recognition model could not be loaded. Please ensure the model file exists.\n\nError: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager = nil
        audioRecorder = nil
        whisperService = nil
    }
}
