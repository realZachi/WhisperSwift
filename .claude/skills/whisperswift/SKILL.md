# WhisperSwift Development Skill

This skill provides context and guidance for developing and maintaining the WhisperSwift macOS application.

## Overview

WhisperSwift is a native macOS menu bar application for cloud-based speech-to-text transcription via the Groq API.

## Key Commands

### Building

```bash
# Open in Xcode
open whisperswift.xcodeproj

# Build from command line
xcodebuild -project whisperswift.xcodeproj -scheme whisperswift -configuration Debug build
```

### Linting

```bash
# Run SwiftLint
swiftlint lint --config .swiftlint.yml

# Run SwiftFormat (check only)
swiftformat . --lint

# Run SwiftFormat (fix)
swiftformat .
```

### Pre-commit Setup

```bash
# Install pre-commit hooks
brew install pre-commit
pre-commit install
```

## Architecture

- **AppDelegate**: Main application lifecycle and recording workflow orchestration
- **Services/**: Core functionality (AudioRecorder, GroqTranscriptionService, HotkeyManager, TextInsertionService)
- **UI/**: User interface components (StatusBarController, SettingsView)

## Data Flow

1. User presses hotkey
2. AudioRecorder captures audio at 16kHz
3. User releases hotkey
4. GroqTranscriptionService sends audio to Groq API
5. TextInsertionService pastes transcription into focused app

## Common Tasks

### Adding a New Service

1. Create Swift file in `whisperswift/Services/`
2. Use Swift actor for thread safety if needed
3. Initialize in AppDelegate's `initializeServices()`
4. Update AGENTS.md with service documentation

### Modifying Hotkey Behavior

- Edit `HotkeyManager.swift` for key detection
- Edit `AppDelegate.swift` for recording gesture logic

### Changing Text Insertion

- Edit `TextInsertionService.swift`
- Consider Accessibility API requirements

## Debugging

Logs are written to `/tmp/whisperswift.log`. Monitor with:

```bash
tail -f /tmp/whisperswift.log
```
