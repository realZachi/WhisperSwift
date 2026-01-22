# WhisperSwift Architecture

This document provides a comprehensive overview of WhisperSwift's architecture, including system design, data flows, and component interactions.

## Table of Contents

- [Overview](#overview)
- [High-Level System Architecture](#high-level-system-architecture)
- [Data Flow Diagrams](#data-flow-diagrams)
- [Component Interaction](#component-interaction)
- [Service Dependencies](#service-dependencies)
- [Detailed Service Flows](#detailed-service-flows)
- [File Structure](#file-structure)
- [Security Considerations](#security-considerations)

## Overview

WhisperSwift is a native macOS menu bar application that provides speech-to-text transcription using the Groq API. The application follows a service-oriented architecture with clear separation of concerns between UI components, service layer, and external API communication.

**Key Characteristics:**
- **Platform**: macOS 13.0+ (Apple Silicon optimized)
- **Language**: Swift 5.0 with SwiftUI
- **Architecture Pattern**: Service-oriented with actor-based concurrency
- **External Dependencies**: Groq API for speech recognition

## High-Level System Architecture

The following diagram shows the overall system architecture:

```mermaid
graph TB
    subgraph "WhisperSwift Application"
        subgraph "UI Layer"
            SBC[StatusBarController]
            SV[SettingsView]
            RPC[RecordingPillController]
        end

        subgraph "Orchestration Layer"
            AD[AppDelegate]
        end

        subgraph "Service Layer"
            HM[HotkeyManager]
            AR[AudioRecorder]
            GTS[GroqTranscriptionService]
            TIS[TextInsertionService]
            CS[ContextService]
            PM[PermissionManager]
            TCR[TextCleanupContextResolver]
        end
    end

    subgraph "External Services"
        GROQ[Groq API]
    end

    subgraph "System APIs"
        AV[AVFoundation]
        AX[Accessibility API]
        NS[NSEvent / CGEvent]
        PB[NSPasteboard]
    end

    AD --> SBC
    AD --> RPC
    AD --> HM
    AD --> AR
    AD --> GTS
    AD --> TIS
    AD --> CS
    AD --> PM
    AD --> TCR

    HM --> NS
    AR --> AV
    TIS --> AX
    TIS --> PB
    PM --> AV
    PM --> AX
    GTS --> GROQ

    style AD fill:#4a90d9,stroke:#2d5a87,color:#fff
    style GROQ fill:#10b981,stroke:#059669,color:#fff
```

## Data Flow Diagrams

### Main Recording and Transcription Flow

This diagram shows the complete data flow from hotkey press to text insertion:

```mermaid
sequenceDiagram
    participant User
    participant HM as HotkeyManager
    participant AD as AppDelegate
    participant AR as AudioRecorder
    participant RPC as RecordingPill
    participant GTS as GroqTranscriptionService
    participant CS as ContextService
    participant TIS as TextInsertionService
    participant App as Target App

    User->>HM: Press Hotkey
    HM->>AD: onKeyDown()
    AD->>AR: startRecording()
    AD->>RPC: show()
    AR-->>RPC: Audio levels (callback)

    Note over User,AR: User speaks...

    User->>HM: Release Hotkey
    HM->>AD: onKeyUp()
    AD->>AR: stopRecording()
    AR-->>AD: AudioRecording

    AD->>RPC: transitionToProcessing()
    AD->>GTS: transcribe(recording)
    GTS-->>AD: Raw transcription

    AD->>GTS: cleanTranscription(text)
    GTS-->>AD: Cleaned text

    AD->>CS: captureSnapshot()
    CS-->>AD: Context snapshot
    AD->>CS: applyContext(text)
    CS-->>AD: Contextualized text

    AD->>TIS: insertText(text)
    TIS->>App: Insert via Accessibility/Paste
    AD->>RPC: hide()
```

### Audio Processing Pipeline

```mermaid
flowchart LR
    subgraph "Audio Capture"
        MIC[Microphone Input]
        AE[AVAudioEngine]
        TAP[Input Tap]
    end

    subgraph "Processing"
        CONV[Sample Rate Converter]
        NORM[Normalizer]
        TRIM[Silence Trimmer]
    end

    subgraph "Output"
        WAV[WAV Data]
        API[Groq API]
    end

    MIC --> AE
    AE --> TAP
    TAP -->|"Native Rate"| CONV
    CONV -->|"16kHz Mono"| NORM
    NORM --> TRIM
    TRIM --> WAV
    WAV -->|"HTTP POST"| API

    style MIC fill:#ef4444,stroke:#dc2626
    style API fill:#10b981,stroke:#059669
```

## Component Interaction

### Service Communication Diagram

```mermaid
graph LR
    subgraph "Event Sources"
        KEY[Keyboard Events]
        UI[UI Actions]
    end

    subgraph "Core Services"
        AD[AppDelegate]
        HM[HotkeyManager]
        AR[AudioRecorder]
        GTS[GroqService]
        TIS[TextInsertion]
    end

    subgraph "Support Services"
        PM[PermissionManager]
        CS[ContextService]
        TCR[TextCleanupResolver]
    end

    KEY --> HM
    UI --> AD
    HM -->|"Key Events"| AD
    AD -->|"Start/Stop"| AR
    AD -->|"Transcribe"| GTS
    AD -->|"Insert"| TIS
    AD -->|"Context"| CS
    AD -->|"Profile"| TCR
    PM -.->|"Check"| AD
    PM -.->|"Check"| TIS
    PM -.->|"Check"| HM
    CS -->|"Profile"| TCR

    style AD fill:#4a90d9,stroke:#2d5a87,color:#fff
```

### State Machine Diagram

The AppDelegate manages the application state through this state machine:

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Recording: Hotkey Down
    Recording --> Processing: Hotkey Up (held > 350ms)
    Recording --> Recording: Hotkey Up (tap < 350ms)\n[wait for double-tap]
    Recording --> LockedRecording: Double-tap detected

    LockedRecording --> Processing: Hotkey Down

    Processing --> Idle: Transcription Complete
    Processing --> SavedState: No Focus Target

    SavedState --> Idle: Timeout / Manual Paste

    note right of Recording: UI shows recording pill\nAudio capture active
    note right of Processing: Sending to Groq API\nUI shows spinner
    note right of LockedRecording: Hands-free mode\nNo hold required
```

## Service Dependencies

### Dependency Graph

```mermaid
graph TD
    subgraph "Application Entry"
        APP[whisperswiftApp]
        AD[AppDelegate]
    end

    subgraph "UI Components"
        SBC[StatusBarController]
        SV[SettingsView]
        RPC[RecordingPillController]
        RPV[RecordingPillView]
    end

    subgraph "Core Services"
        HM[HotkeyManager]
        AR[AudioRecorder]
        GTS[GroqTranscriptionService]
        TIS[TextInsertionService]
    end

    subgraph "Support Services"
        PM[PermissionManager]
        CS[ContextService]
        TCR[TextCleanupContextResolver]
        TCP[TextCleanupProfile]
    end

    APP --> AD
    AD --> SBC
    AD --> RPC
    AD --> HM
    AD --> AR
    AD --> GTS
    AD --> TIS
    AD --> CS
    AD --> TCR
    AD --> PM

    SBC --> SV
    RPC --> RPV

    HM -.-> PM
    TIS -.-> PM
    AR -.-> PM

    GTS --> TCP
    TCR --> TCP
    CS --> TCR

    classDef actor fill:#fbbf24,stroke:#d97706
    classDef singleton fill:#a78bfa,stroke:#7c3aed
    class AR,GTS actor
    class PM singleton
```

### Framework Dependencies

```mermaid
graph LR
    subgraph "WhisperSwift Services"
        AR[AudioRecorder]
        HM[HotkeyManager]
        TIS[TextInsertionService]
        PM[PermissionManager]
        GTS[GroqService]
    end

    subgraph "Apple Frameworks"
        AVF[AVFoundation]
        ACC[Accelerate]
        COC[Cocoa/AppKit]
        CAR[Carbon]
        FND[Foundation]
    end

    AR --> AVF
    AR --> ACC
    HM --> COC
    HM --> CAR
    TIS --> COC
    TIS --> CAR
    PM --> AVF
    PM --> COC
    GTS --> FND

    style AVF fill:#3b82f6,stroke:#2563eb
    style ACC fill:#3b82f6,stroke:#2563eb
    style COC fill:#3b82f6,stroke:#2563eb
    style CAR fill:#3b82f6,stroke:#2563eb
    style FND fill:#3b82f6,stroke:#2563eb
```

## Detailed Service Flows

### Recording Workflow

The recording workflow handles audio capture with gesture detection:

```mermaid
flowchart TD
    START([Hotkey Down]) --> CHECK{Already Recording?}
    CHECK -->|No| APICHECK{API Key\nConfigured?}
    CHECK -->|Yes| LOCKED{Locked Mode?}

    APICHECK -->|No| ALERT[Show API Key Alert]
    APICHECK -->|Yes| RECORD[Start Recording]

    ALERT --> END1([End])
    RECORD --> SHOW[Show Recording Pill]
    SHOW --> CAPTURE[Capture Audio]

    LOCKED -->|Yes| STOP[Stop Recording]
    LOCKED -->|No| IGNORE[Ignore Key Down]

    CAPTURE --> KEYUP([Hotkey Up])
    KEYUP --> DURATION{Hold Duration}

    DURATION -->|"> 350ms"| STOP
    DURATION -->|"< 350ms"| DOUBLETAP{Double-tap\nWindow?}

    DOUBLETAP -->|"Within 500ms"| LOCK[Enable Locked Mode]
    DOUBLETAP -->|"Expired"| STOP

    LOCK --> CAPTURE
    STOP --> PROCESS[Process Audio]
    PROCESS --> TRANSCRIBE[Send to Groq]
    TRANSCRIBE --> INSERT[Insert Text]
    INSERT --> END2([End])

    style START fill:#10b981,stroke:#059669
    style END1 fill:#6b7280,stroke:#4b5563
    style END2 fill:#10b981,stroke:#059669
    style STOP fill:#ef4444,stroke:#dc2626
```

### Transcription Workflow

```mermaid
flowchart TD
    START([Audio Recording]) --> SIZE{File Size\n> 25MB?}

    SIZE -->|No| SINGLE[Single Request]
    SIZE -->|Yes| CHUNK[Chunk Audio]

    CHUNK --> LOOP[For Each Chunk]
    LOOP --> SEND[Send to Groq API]
    SEND --> NEXT{More Chunks?}
    NEXT -->|Yes| LOOP
    NEXT -->|No| MERGE[Merge Transcripts]

    SINGLE --> SEND2[Send to Groq API]
    SEND2 --> CLEAN[Clean Artifacts]

    MERGE --> OVERLAP[Remove Overlap]
    OVERLAP --> CLEAN

    CLEAN --> PROFILE[Get Cleanup Profile]
    PROFILE --> LLM[LLM Cleanup]
    LLM --> CONTEXT[Apply Context]
    CONTEXT --> RESULT([Final Text])

    style START fill:#4a90d9,stroke:#2d5a87
    style RESULT fill:#10b981,stroke:#059669
```

### Permission Handling Flow

```mermaid
flowchart TD
    START([App Launch]) --> MIC{Microphone\nAccess?}

    MIC -->|Authorized| MICOK[Microphone Ready]
    MIC -->|Not Determined| MICREQ[Request Microphone]
    MIC -->|Denied| MICWARN[Log Warning]

    MICREQ --> MICRESULT{Granted?}
    MICRESULT -->|Yes| MICOK
    MICRESULT -->|No| MICWARN

    MICOK --> AX{Accessibility\nAccess?}
    MICWARN --> AX

    AX -->|Trusted| AXOK[Full Functionality]
    AX -->|Not Trusted| AXPROMPT{First Time?}

    AXPROMPT -->|Yes| AXREQ[Show System Dialog]
    AXPROMPT -->|No| AXWARN[Limited Mode]

    AXREQ --> AXWARN
    AXOK --> READY([Services Ready])
    AXWARN --> LIMITED([Limited Mode])

    style START fill:#4a90d9,stroke:#2d5a87
    style READY fill:#10b981,stroke:#059669
    style LIMITED fill:#fbbf24,stroke:#d97706
```

### Text Insertion Flow

```mermaid
flowchart TD
    START([Insert Text]) --> EMPTY{Text Empty?}
    EMPTY -->|Yes| ENDEMPTY([Return .empty])

    EMPTY -->|No| AXTRUST{Accessibility\nTrusted?}
    AXTRUST -->|No| CLIPBOARD[Copy to Clipboard]
    CLIPBOARD --> PROMPT[Prompt for Accessibility]
    PROMPT --> ENDCLIP([Return .copiedToClipboard])

    AXTRUST -->|Yes| FOCUSED{Focused\nElement?}
    FOCUSED -->|No| FRONTAPP{Frontmost\nApp?}

    FRONTAPP -->|Yes| PASTE[Clipboard Paste]
    FRONTAPP -->|No| SAVE[Save to Clipboard]
    SAVE --> ENDNO([Return .noFocusedTarget])

    FOCUSED -->|Yes| BLACKLIST{App\nBlacklisted?}
    BLACKLIST -->|Yes| PASTE

    BLACKLIST -->|No| AXINSERT[Try AX Insert]
    AXINSERT --> AXRESULT{Success?}
    AXRESULT -->|Yes| ENDOK([Return .inserted])
    AXRESULT -->|No| PASTE

    PASTE --> SIMCMDV[Simulate Cmd+V]
    SIMCMDV --> RESTORE[Restore Clipboard]
    RESTORE --> ENDOK

    style START fill:#4a90d9,stroke:#2d5a87
    style ENDOK fill:#10b981,stroke:#059669
    style ENDCLIP fill:#fbbf24,stroke:#d97706
    style ENDEMPTY fill:#6b7280,stroke:#4b5563
    style ENDNO fill:#ef4444,stroke:#dc2626
```

## File Structure

```
whisperswift/
├── AppDelegate.swift              # App lifecycle, service orchestration
├── whisperswiftApp.swift          # SwiftUI entry point (@main)
├── Services/
│   ├── AudioRecorder.swift        # Audio capture (actor)
│   ├── GroqTranscriptionService.swift  # STT API communication (actor)
│   ├── HotkeyManager.swift        # Global hotkey detection
│   ├── TextInsertionService.swift # Text paste/insertion
│   ├── PermissionManager.swift    # Permission handling (singleton)
│   ├── ContextService.swift       # App context detection
│   ├── TextCleanupContextResolver.swift
│   └── TextCleanupProfile.swift
├── UI/
│   ├── StatusBarController.swift  # Menu bar icon and menu
│   ├── SettingsView.swift         # SwiftUI settings window
│   ├── RecordingPillController.swift
│   └── RecordingPillView.swift
└── Assets.xcassets/               # App icons and assets
```

## Security Considerations

### Data Flow Security

```mermaid
flowchart LR
    subgraph "Local Device"
        MIC[Microphone]
        APP[WhisperSwift]
        CLIP[Clipboard]
        LOG["/tmp/whisperswift.log"]
    end

    subgraph "Cloud"
        GROQ[Groq API]
    end

    MIC -->|"Audio Samples"| APP
    APP -->|"WAV Data (HTTPS)"| GROQ
    GROQ -->|"Text (HTTPS)"| APP
    APP -->|"Scrubbed Logs"| LOG
    APP -->|"Text"| CLIP

    style GROQ fill:#10b981,stroke:#059669
```

**Security measures:**
- API keys stored locally in UserDefaults (not transmitted except to Groq)
- All API communication over HTTPS
- Audio data not persisted locally after transcription
- Log files scrub sensitive data (API keys, emails, tokens)
- No telemetry or analytics collection
