# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LocalWhisper is a native macOS menu bar application for local, private speech-to-text transcription. It uses whisper.cpp (OpenAI Whisper) with Metal GPU acceleration on Apple Silicon. Users hold a hotkey (Fn, Option, or Control), speak, release, and transcribed text is automatically inserted into the focused application.

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
│   ├── WhisperService.swift        # Speech recognition (whisper.cpp C API, Swift actor)
│   ├── AudioRecorder.swift         # Audio capture, 16kHz conversion, normalization (actor)
│   ├── HotkeyManager.swift         # Global hotkey detection (NSEvent + CGEvent tap)
│   ├── PermissionManager.swift     # Microphone & accessibility permissions (singleton)
│   └── TextInsertionService.swift  # Text insertion via clipboard/paste or accessibility
├── UI/
│   ├── StatusBarController.swift   # Menu bar icon & menu (idle/recording/processing states)
│   └── SettingsView.swift          # SwiftUI settings window (hotkey, permissions, about)
└── Assets.xcassets/
```

**Data Flow**: Hotkey press → AudioRecorder captures → Hotkey release → WhisperService transcribes → TextInsertionService pastes

**Key Dependencies**:
- whisper.cpp v1.7.5 (XCFramework) - bridged via `localwhisper-Bridging-Header.h`
- Whisper Small model: `Models/ggml-small.bin` (465MB, bundled)

## Coding Conventions

- Swift style: 4-space indentation
- Types: `UpperCamelCase`, methods/vars: `lowerCamelCase`
- UI code in `localwhisper/UI/`, service logic in `localwhisper/Services/`
- Use Swift actors for thread-safe services (WhisperService, AudioRecorder)

## Important Notes

- **Sandbox disabled**: Required for global hotkeys and accessibility API access
- **Debug logging**: Writes to `/tmp/localwhisper.log`
- **Default language**: German (hardcoded in WhisperService, supports 90+ languages)
- **Entitlements**: Edit `localwhisper/localwhisper.entitlements` carefully when adding capabilities
- **No network calls**: Privacy-first design, no telemetry or cloud features
