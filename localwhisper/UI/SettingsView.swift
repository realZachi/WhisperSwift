//
//  SettingsView.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            PermissionsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 280)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("selectedHotkey") private var selectedHotkey = "fn"
    @AppStorage("playSounds") private var playSounds = true
    @ObservedObject private var modelStatus = WhisperModelStatus.shared

    var body: some View {
        Form {
            Section("Hotkey") {
                Picker("Push-to-Talk Key:", selection: $selectedHotkey) {
                    Text("Fn (Globe) Key").tag("fn")
                    Text("Right Option Key").tag("option")
                    Text("Right Control Key").tag("control")
                }
                .pickerStyle(.menu)

                Text("Hold the key to record, release to transcribe")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Feedback") {
                Toggle("Play sounds", isOn: $playSounds)
            }

            Section("Model") {
                HStack {
                    Text("Whisper Model:")
                    Spacer()
                    Text(modelStatus.modelName)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    switch modelStatus.phase {
                    case .ready:
                        Label("Ready", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .downloading:
                        ProgressView(value: modelStatus.progressFraction ?? 0)
                        Text(modelStatus.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .failed:
                        Label("Download failed", systemImage: "xmark.octagon.fill")
                            .foregroundColor(.red)
                        Text(modelStatus.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry Download") {
                            modelStatus.requestDownload?()
                        }
                        .buttonStyle(.bordered)
                    case .idle:
                        Text(modelStatus.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Download Model") {
                            modelStatus.requestDownload?()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text("Supports German, English, and 90+ other languages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PermissionsView: View {
    @State private var hasMicrophoneAccess = false
    @State private var hasAccessibilityAccess = false

    var body: some View {
        Form {
            Section("Required Permissions") {
                PermissionRow(
                    title: "Microphone",
                    description: "Required for voice recording",
                    isGranted: hasMicrophoneAccess,
                    action: openMicrophoneSettings
                )

                PermissionRow(
                    title: "Accessibility",
                    description: "Required for global hotkey and text insertion",
                    isGranted: hasAccessibilityAccess,
                    action: openAccessibilitySettings
                )
            }

            Section {
                Button("Refresh Status") {
                    checkPermissions()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        hasMicrophoneAccess = PermissionManager.shared.hasMicrophoneAccess
        hasAccessibilityAccess = PermissionManager.shared.hasAccessibilityAccess
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        _ = PermissionManager.shared.requestAccessibilityAccess()
        PermissionManager.shared.openAccessibilitySettings()
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .fontWeight(.medium)

                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("LocalWhisper")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .foregroundColor(.secondary)

            Text("Push-to-talk speech recognition powered by WhisperKit")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()

            Text("WhisperKit by argmaxinc")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
    }
}

#Preview {
    SettingsView()
}
