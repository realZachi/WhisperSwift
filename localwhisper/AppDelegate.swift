//
//  AppDelegate.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager?
    private var whisperService: WhisperService?
    private var audioRecorder: AudioRecorder?
    private var textInsertionService: TextInsertionService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize status bar
        statusBarController = StatusBarController()

        // Initialize services
        Task {
            await initializeServices()
        }
    }

    private func initializeServices() async {
        // Check and request permissions
        await PermissionManager.shared.requestPermissions()

        // Initialize text insertion service
        textInsertionService = TextInsertionService()

        // Initialize audio recorder
        audioRecorder = AudioRecorder()

        // Initialize Whisper service (loads model)
        do {
            whisperService = try await WhisperService()
            print("Whisper model loaded successfully")
        } catch {
            print("Failed to load Whisper model: \(error)")
            await showModelLoadError(error)
        }

        // Initialize hotkey manager
        hotkeyManager = HotkeyManager(
            onKeyDown: { [weak self] in
                Task { await self?.startRecording() }
            },
            onKeyUp: { [weak self] in
                Task { await self?.stopRecordingAndTranscribe() }
            }
        )

        print("LocalWhisper initialized successfully")
    }

    private func startRecording() async {
        guard let audioRecorder = audioRecorder else { return }

        await MainActor.run {
            statusBarController?.state = .recording
        }

        do {
            try await audioRecorder.startRecording()
            print("Recording started")
        } catch {
            print("Failed to start recording: \(error)")
            await MainActor.run {
                statusBarController?.state = .idle
            }
        }
    }

    private func stopRecordingAndTranscribe() async {
        guard let audioRecorder = audioRecorder,
              let whisperService = whisperService,
              let textInsertionService = textInsertionService else { return }

        await MainActor.run {
            statusBarController?.state = .processing
        }

        // Stop recording and get audio samples
        let audioSamples = await audioRecorder.stopRecording()

        guard !audioSamples.isEmpty else {
            print("No audio recorded")
            await MainActor.run {
                statusBarController?.state = .idle
            }
            return
        }

        print("Recorded \(audioSamples.count) samples, transcribing...")

        // Transcribe audio
        do {
            let transcription = try await whisperService.transcribe(audioSamples: audioSamples)

            if !transcription.isEmpty {
                print("Transcription: \(transcription)")

                // Insert text into focused application
                await MainActor.run {
                    textInsertionService.insertText(transcription)
                }
            } else {
                print("Empty transcription result")
            }
        } catch {
            print("Transcription failed: \(error)")
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
