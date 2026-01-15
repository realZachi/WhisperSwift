# whisperswift

A native macOS menu bar application for lightning-fast speech-to-text transcription using the Groq API. Hold a hotkey, speak, release—your words instantly appear in any text field.

## Features

### Push-to-Talk Dictation
- **Three hotkey options**: Fn/Globe key, Right Option, or Right Control
- **System-wide operation**: Works in any application with text input
- **Zero-click workflow**: Hold to record, release to transcribe and insert

### High-Quality Transcription
- **Powered by Groq**: Uses Whisper Large v3 Turbo for accurate, near-instant transcription
- **Blazing fast**: Groq's LPU inference runs Whisper at **220x realtime speed** — a 10-second recording transcribes in ~45ms
- **Multi-language support**: Configure any language code supported by Whisper
- **Smart cleanup**: Optional AI-powered cleanup using **Kimi K2** to remove filler words, false starts, and verbal stumbles while preserving your exact wording

### Intelligent Context Awareness
- **Filename recognition**: Automatically detects filenames from your active window or document
- **Spoken-to-written normalization**: Converts "context service dot swift" → `ContextService.swift`
- **CamelCase and extension handling**: Understands various file naming conventions

### Visual Feedback
- **Animated recording indicator**: A floating pill with real-time audio waveform visualization
- **Menu bar status**: Clear visual states for idle, recording, and processing
- **Smooth transitions**: Elegant animations between recording and processing states

### Smart Text Insertion
- **Accessibility API integration**: Direct text insertion at cursor position (preferred method)
- **Intelligent fallback**: Automatic clipboard-based insertion for apps that need it
- **Application awareness**: Maintains a blacklist of apps requiring special handling (VS Code, browsers, etc.)

## How It Works

```
1. Hold hotkey (Fn/Option/Control)
       ↓
2. Speak your text
       ↓
3. Release hotkey
       ↓
4. Audio is processed (normalized, silence-trimmed)
       ↓
5. Sent to Groq API for transcription
       ↓
6. Optional: AI cleanup removes filler words
       ↓
7. Context service applies filename corrections
       ↓
8. Text inserted into focused application
```

## Prerequisites

- macOS 13.0 or later (Apple Silicon optimized)
- A valid [Groq API Key](https://console.groq.com/)
- Internet connection

## Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/whisperswift.git
cd whisperswift

# Open in Xcode
open whisperswift.xcodeproj

# Or build from command line
xcodebuild -project whisperswift.xcodeproj -scheme whisperswift -configuration Release build
```

### Option 2: Download Release
Download the latest `.app` from the [Releases](https://github.com/yourusername/whisperswift/releases) page.

## Setup

1. **Launch whisperswift** — it will appear in your menu bar
2. **Grant permissions** when prompted:
   - **Microphone**: Required to capture your voice
   - **Accessibility**: Required for global hotkeys and direct text insertion
3. **Configure your API key**:
   - Click the menu bar icon → Settings
   - Enter your Groq API key
   - *Alternative*: Set the `GROQ_API_KEY` environment variable

## Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| Hotkey | Fn/Globe | Push-to-talk trigger key |
| API Key | — | Your Groq API authentication key |
| Model | `whisper-large-v3-turbo` | Groq transcription model |
| Language | `de` | ISO language code for transcription |
| Play Sounds | On | Audio feedback during recording |

## Permissions

whisperswift requires two system permissions:

### Microphone Access
Needed to capture your voice input. The app will prompt you on first launch.

### Accessibility Access
Required for:
- Detecting global hotkey presses (especially the Fn key)
- Inserting text directly into applications via the Accessibility API
- Capturing window context for intelligent filename detection

*Without Accessibility permission, the app falls back to clipboard-based text insertion.*

## Technical Details

### Audio Processing Pipeline
- **Sample rate**: 16 kHz (optimized for speech recognition)
- **Format**: Mono PCM, converted to WAV for upload
- **Normalization**: Automatic gain adjustment using vDSP SIMD operations
- **Silence detection**: RMS-based trimming with 200ms speech padding

### Architecture
- **Swift Actors** for thread-safe audio recording and API communication
- **Dual hotkey detection**: CGEvent tap (primary) with NSEvent fallback
- **Concurrent processing**: Async/await throughout for responsive UI

### Text Insertion Strategy
1. **Primary**: Accessibility API (`kAXSelectedTextAttribute` or `kAXValueAttribute`)
2. **Fallback**: Clipboard + simulated Cmd+V for blacklisted apps
3. **Clipboard preservation**: Original clipboard content is restored after paste

### Blacklisted Applications
These apps receive clipboard-based insertion due to custom text handling:
- VS Code and variants
- Chrome, Firefox, Safari, Arc, and other browsers
- Electron-based applications

## Economics

Groq API pricing is approximately **$0.04 per hour** of audio processed ($4 per 100 hours). This is significantly more cost-effective than:
- Running local inference on consumer hardware
- Alternative cloud transcription APIs
- Subscription-based dictation services

## Privacy

- Audio is sent to Groq's servers for transcription
- No audio is stored locally or by the app
- Your API key is stored in macOS UserDefaults (or can be set via environment variable)
- See [Groq's Privacy Policy](https://groq.com/privacy-policy/) for their data handling practices

## Troubleshooting

### Text isn't being inserted
1. Check that Accessibility permission is granted (Settings → Permissions)
2. For VS Code/browsers, text is copied to clipboard—use Cmd+V to paste

### Hotkey not detected
1. Ensure Accessibility permission is enabled
2. Try a different hotkey option in Settings
3. Check that no other app is capturing the same key

### Poor transcription quality
1. Verify your microphone is working correctly
2. Speak clearly and at a moderate pace
3. Try adjusting the language setting to match your speech

### Logs
Debug logs are written to `/tmp/whisperswift.log` for troubleshooting.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Credits

- **Groq** for the lightning-fast Whisper API (220x realtime inference)
- **Moonshot AI** for Kimi K2, used for transcript cleanup
- **Apple** for SwiftUI and the Accessibility framework
- Built with native Swift for optimal macOS integration
