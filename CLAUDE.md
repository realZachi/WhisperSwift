# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LocalWhisper is a native macOS menu bar application for cloud-based speech-to-text transcription via the Groq API. Users hold a hotkey (Fn, Option, or Control), speak, release, and the transcribed text is automatically inserted into the focused application.

- **Platform**: macOS 13.0+, Apple Silicon optimized
- **Language**: Swift 5.0, SwiftUI
- **License**: MIT

## Build Commands

```bash
# Open in Xcode (recommended for menu bar app behavior and permissions)
open localwhisper.xcodeproj

# Build from CLI
xcodebuild -project localwhisper.xcodeproj -scheme localwhisper -configuration Debug build
```

**WICHTIG**: Nach jeder Code-Änderung, die einen Build erfordert (Swift-Dateien, Ressourcen, Projekteinstellungen), MUSS automatisch gebaut werden mit:
```bash
xcodebuild -project localwhisper.xcodeproj -scheme localwhisper -configuration Debug build
```

No test target exists currently. If adding tests, use XCTest and place files under a `localwhisperTests/` target.

## Architecture

The app follows a service-oriented architecture:

```
localwhisper/
├── AppDelegate.swift       # Lifecycle & service orchestration, recording workflow
├── localwhisperApp.swift   # SwiftUI entry point
├── Services/
│   ├── GroqTranscriptionService.swift # Speech recognition (Groq API, Swift actor)
│   ├── AudioRecorder.swift         # Audio capture, 16kHz conversion, normalization (actor)
│   ├── HotkeyManager.swift         # Global hotkey detection (NSEvent + CGEvent tap)
│   ├── PermissionManager.swift     # Microphone & accessibility permissions (singleton)
│   └── TextInsertionService.swift  # Text insertion via clipboard/paste or accessibility
├── UI/
│   ├── StatusBarController.swift   # Menu bar icon & menu (idle/recording/processing states)
│   └── SettingsView.swift          # SwiftUI settings window (hotkey, permissions, about)
└── Assets.xcassets/
```

**Data Flow**: Hotkey press → AudioRecorder captures → Hotkey release → GroqTranscriptionService transcribes → TextInsertionService pastes

**Key Dependencies**:
- Groq API (HTTP multipart transcription endpoint)

## Coding Conventions

- Swift style: 4-space indentation
- Types: `UpperCamelCase`, methods/vars: `lowerCamelCase`
- UI code in `localwhisper/UI/`, service logic in `localwhisper/Services/`
- Use Swift actors for thread-safe services (GroqTranscriptionService, AudioRecorder)

## Important Notes

- **Sandbox disabled**: Required for global hotkeys and accessibility API access
- **Debug logging**: Writes to `/tmp/localwhisper.log`
- **Default language**: German (default in UserDefaults, override in Settings)
- **Entitlements**: Edit `localwhisper/localwhisper.entitlements` carefully when adding capabilities
- **Network usage**: Active internet required; audio is sent to Groq for transcription
