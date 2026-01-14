# LocalWhisper

A macOS menu bar app for push-to-talk speech recognition powered by whisper.cpp.

## Features

- **Push-to-Talk**: Hold Fn key to record, release to transcribe
- **Multilingual**: Supports German, English, and 90+ languages (auto-detection)
- **Local Processing**: All transcription happens on-device using whisper.cpp
- **Apple Silicon Optimized**: Uses Metal GPU acceleration for fast inference
- **Text Insertion**: Automatically inserts transcribed text into any focused text field

## Requirements

- macOS 13.0 or later
- Apple Silicon Mac (M1/M2/M3/M4)
- ~150MB disk space for the Whisper model

## Setup Instructions

### 1. Open in Xcode

```bash
open localwhisper.xcodeproj
```

### 2. Link whisper.xcframework

The XCFramework is already downloaded in `localwhisper/whisper.xcframework`.

1. In Xcode, select the **localwhisper** target
2. Go to **General** → **Frameworks, Libraries, and Embedded Content**
3. Click **+** → **Add Other...** → **Add Files...**
4. Select `localwhisper/whisper.xcframework`
5. Set **Embed** to **Embed & Sign**

### 3. Configure Project Settings

#### Info.plist
The `Info.plist` file is already created. In Xcode:
1. Select the project in the navigator
2. Select the `localwhisper` target
3. Go to **Build Settings**
4. Search for `Info.plist File`
5. Set to `localwhisper/Info.plist`

#### Entitlements
1. In **Build Settings**, search for `Code Signing Entitlements`
2. Set to `localwhisper/localwhisper.entitlements`

#### Bridging Header
1. In **Build Settings**, search for `Objective-C Bridging Header`
2. Set to `localwhisper/localwhisper-Bridging-Header.h`

#### Disable App Sandbox
1. In **Signing & Capabilities**, remove "App Sandbox" if present
2. The entitlements file already has sandbox disabled

### 4. Download Whisper Model

Download the multilingual base model (~142MB):

```bash
# Create models directory
mkdir -p localwhisper/Resources/models

# Download model
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" \
     -o localwhisper/Resources/models/ggml-base.bin
```

### 5. Add Model to Xcode Project

1. In Xcode, right-click on the `localwhisper` folder
2. Select **Add Files to "localwhisper"...**
3. Navigate to `Resources/models/ggml-base.bin`
4. Ensure "Copy items if needed" is checked
5. Add to target `localwhisper`

### 6. Grant Permissions

On first launch, you'll need to grant:

1. **Microphone Access**: Required for voice recording
2. **Accessibility Access**: Required for global hotkey and text insertion

Go to **System Settings > Privacy & Security** to grant these permissions.

## Usage

1. Launch LocalWhisper - it appears in the menu bar (waveform icon)
2. Click any text field in any application
3. Hold the **Fn** key and speak
4. Release the key - your speech is transcribed and inserted

## Hotkey Options

In the Settings menu, you can change the hotkey to:
- **Fn (Globe) Key** - Default
- **Right Option Key**
- **Right Control Key**

## Troubleshooting

### "Model not found" error
Ensure `ggml-base.bin` is in the app bundle. Check that it's added to the target in Xcode.

### Hotkey not working
1. Check Accessibility permissions in System Settings
2. Try using Option key instead of Fn
3. Restart the app after granting permissions

### No transcription output
1. Check Microphone permissions
2. Ensure you're speaking clearly
3. Check the console for error messages

## Technical Details

- **Audio Format**: 16kHz, mono, Float32 PCM
- **Model**: ggml-base.bin (multilingual)
- **Acceleration**: Metal GPU (Apple Silicon)
- **Framework**: SwiftUI + AppKit

## License

MIT License

## Acknowledgments

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) by ggerganov
- OpenAI Whisper model
