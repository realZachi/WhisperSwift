//
//  SettingsView.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import SwiftUI

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
    @AppStorage("groqApiKey") private var groqApiKey = ""
    @AppStorage("groqModel") private var groqModel = "whisper-large-v3-turbo"
    @AppStorage("groqLanguage") private var groqLanguage = "de"

    var body: some View {
        Form {
            Section("Hotkey") {
                Picker("Push-to-Talk Key:", selection: $selectedHotkey) {
                    Text("Fn (Globe) Key").tag("fn")
                    Text("Right Option Key").tag("option")
                    Text("Right Control Key").tag("control")
                }
                .pickerStyle(.menu)

                Text("Hold the key to record. Double-tap to lock recording hands-free.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Feedback") {
                Toggle("Play sounds", isOn: $playSounds)
            }

            Section("Groq API") {
                SecureField("API Key", text: $groqApiKey)
                TextField("Model", text: $groqModel)
                TextField("Language", text: $groqLanguage)
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
        PermissionManager.shared.openMicrophoneSettings()
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

            Text("WhisperSwift")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .foregroundColor(.secondary)

            Text("Push-to-talk speech recognition powered by Groq")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 4) {
                Text("Developed by Mahmoud Ali Khan")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Link("github.com/realZachi", destination: URL(string: "https://github.com/realZachi")!)
                    .font(.caption)
            }
        }
        .padding(32)
    }
}

#Preview {
    SettingsView()
}
