# WhisperSwift Architecture

## Overview

WhisperSwift is a native macOS menu bar application that provides speech-to-text transcription using the Groq API. The app follows a service-oriented architecture with clear separation of concerns.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WhisperSwift App                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    ┌──────────────────────────────────────────┐   │
│  │   UI Layer  │    │              Service Layer               │   │
│  ├─────────────┤    ├──────────────────────────────────────────┤   │
│  │             │    │                                          │   │
│  │ StatusBar   │◄───┤  AppDelegate (Orchestration)             │   │
│  │ Controller  │    │    │                                     │   │
│  │             │    │    ├── HotkeyManager                     │   │
│  │ Settings    │    │    │      (Global key detection)         │   │
│  │ View        │    │    │                                     │   │
│  │             │    │    ├── AudioRecorder                     │   │
│  │ Recording   │◄───┤    │      (Audio capture, 16kHz)         │   │
│  │ Pill        │    │    │                                     │   │
│  │             │    │    ├── GroqTranscriptionService          │   │
│  └─────────────┘    │    │      (Speech-to-text API)           │   │
│                     │    │                                     │   │
│                     │    ├── TextInsertionService              │   │
│                     │    │      (Paste/Accessibility)          │   │
│                     │    │                                     │   │
│                     │    ├── ContextService                    │   │
│                     │    │      (App context detection)        │   │
│                     │    │                                     │   │
│                     │    └── PermissionManager                 │   │
│                     │           (Mic/Accessibility)            │   │
│                     │                                          │   │
│                     └──────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │     Groq API        │
                         │  (Cloud STT Service)│
                         └─────────────────────┘
```

## Component Details

### AppDelegate (Orchestration)

**File**: `whisperswift/AppDelegate.swift`

The AppDelegate serves as the central coordinator for the application:

- Initializes all services on app launch
- Manages the recording workflow state machine
- Handles hotkey events (down/up) and gesture detection
- Coordinates data flow between services

**State Machine**:
```
         ┌────────┐
         │  Idle  │◄──────────────────────┐
         └───┬────┘                       │
             │ hotkey down                │
             ▼                            │
       ┌──────────┐                       │
       │Recording │────────┐              │
       └──────────┘        │              │
             │             │double-tap    │
             │hotkey up    │              │
             ▼             ▼              │
      ┌───────────┐  ┌──────────┐        │
      │Processing │  │  Locked  │────────┤
      └─────┬─────┘  │Recording │hotkey  │
            │        └──────────┘down    │
            │                            │
            └────────────────────────────┘
                   transcription done
```

### HotkeyManager

**File**: `whisperswift/Services/HotkeyManager.swift`

Detects global hotkey presses using:
- `NSEvent` global monitors
- `CGEvent` tap for low-level detection

Supports a configurable push-to-talk key recorded in Settings, including standard keys,
function keys, and left/right modifier keys.

### AudioRecorder

**File**: `whisperswift/Services/AudioRecorder.swift`

Swift actor for thread-safe audio capture:
- Uses AVAudioEngine for recording
- Converts to 16kHz mono for Groq API
- Normalizes audio levels
- Provides real-time level metering for UI

### GroqTranscriptionService

**File**: `whisperswift/Services/GroqTranscriptionService.swift`

Swift actor for API communication:
- Sends audio to Groq's Whisper endpoint
- Handles chunking for long recordings
- Performs text cleanup with LLM
- Manages API key storage

### TextInsertionService

**File**: `whisperswift/Services/TextInsertionService.swift`

Inserts transcribed text into applications:
- Primary: Accessibility API (AXUIElement)
- Fallback: Clipboard + simulated paste
- Handles edge cases (no focus, no text field)

### ContextService

**File**: `whisperswift/Services/ContextService.swift`

Detects application context:
- Current application bundle ID
- Window title
- Document name

Used for app-aware text formatting.

### UI Components

**StatusBarController**: Menu bar icon and dropdown menu
**SettingsView**: SwiftUI settings window
**RecordingPillController**: Floating recording indicator

## Data Flow

### Recording Flow

```
1. User Press Hotkey
        │
        ▼
2. HotkeyManager.onKeyDown()
        │
        ▼
3. AppDelegate.handleHotkeyDown()
        │
        ▼
4. AudioRecorder.startRecording()
        │
        ▼
   [User speaks...]
        │
        ▼
5. User Release Hotkey
        │
        ▼
6. HotkeyManager.onKeyUp()
        │
        ▼
7. AppDelegate.handleHotkeyUp()
        │
        ▼
8. AudioRecorder.stopRecording() → Recording
        │
        ▼
9. GroqTranscriptionService.transcribe(recording)
        │
        ▼
10. GroqTranscriptionService.cleanTranscription()
        │
        ▼
11. ContextService.applyContext()
        │
        ▼
12. TextInsertionService.insertText()
        │
        ▼
13. Text appears in focused app
```

## Security Considerations

- API keys stored in UserDefaults (local only)
- Audio sent to Groq API over HTTPS
- No audio persisted locally after transcription
- Logs written to /tmp with sensitive data scrubbed

## Dependencies

### System Frameworks
- AppKit (UI, Accessibility)
- AVFoundation (Audio)
- Carbon (Hotkeys)

### External Services
- Groq API (Speech-to-text)

## File Structure

```
whisperswift/
├── AppDelegate.swift           # App lifecycle, orchestration
├── whisperswiftApp.swift       # SwiftUI entry point
├── Services/
│   ├── AudioRecorder.swift     # Audio capture
│   ├── ContextService.swift    # App context detection
│   ├── GroqTranscriptionService.swift  # STT API
│   ├── HotkeyManager.swift     # Global hotkeys
│   ├── PermissionManager.swift # Permissions
│   ├── TextCleanupContextResolver.swift
│   └── TextInsertionService.swift  # Text paste
├── UI/
│   ├── RecordingPillController.swift
│   ├── SettingsView.swift
│   └── StatusBarController.swift
└── Assets.xcassets/
```
