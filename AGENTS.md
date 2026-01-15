# Repository Guidelines

## Project Structure & Module Organization
- `whisperswift/` holds the Swift app sources.
  - `whisperswift/UI/` contains SwiftUI views (menu bar, settings).
  - `whisperswift/Services/` contains app services (audio capture, hotkeys, permissions, whisper inference).
  - `whisperswift/Assets.xcassets/` contains icons and color assets.
- Models are downloaded at runtime and stored under the app support directory (no bundled model binaries).
- `whisperswift.xcodeproj/` is the Xcode project definition.

## Build, Test, and Development Commands
- Open in Xcode: `open whisperswift.xcodeproj` (recommended for running the menu bar app).
- Build from CLI: `xcodebuild -project whisperswift.xcodeproj -scheme whisperswift -configuration Debug build`.
- Run via Xcode for menu bar behavior and permissions prompts.

## DMG Release Build (Styled)
Use a fresh release derived data folder (avoids asset copy permission issues after icon changes).

```bash
# Release build (Developer ID + timestamp)
xcodebuild -project whisperswift.xcodeproj -scheme whisperswift -configuration Release \
  -derivedDataPath build/DerivedDataRelease \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
  DEVELOPMENT_TEAM=<TEAMID> \
  OTHER_CODE_SIGN_FLAGS="--timestamp" build

# Create styled DMG
APP_NAME="WhisperSwift"
VOL_NAME="WhisperSwift"
DERIVED="build/DerivedDataRelease"
APP_PATH="$DERIVED/Build/Products/Release/${APP_NAME}.app"
DMG_RW="build/${APP_NAME}.rw.dmg"
DMG_FINAL="build/${APP_NAME}.dmg"

rm -f "$DMG_RW" "$DMG_FINAL"
hdiutil create -size 200m -fs HFS+ -volname "$VOL_NAME" -ov "$DMG_RW"
MOUNT_INFO=$(hdiutil attach -nobrowse -readwrite "$DMG_RW")
DEVICE=$(echo "$MOUNT_INFO" | awk '/^\\/dev\\// {print $1; exit}')
MOUNT_POINT=$(echo "$MOUNT_INFO" | awk '/Volumes\\/[^ ]+/ {print $3; exit}')

cp -R "$APP_PATH" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"
mkdir -p "$MOUNT_POINT/.background"

# Use your own bg.png or generate one, then set Finder layout via osascript
# (see CLAUDE.md for the full layout script).

hdiutil detach "$DEVICE"
hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_FINAL"
rm -f "$DMG_RW"
```

## Coding Style & Naming Conventions
- Swift style: 4-space indentation; types in `UpperCamelCase`, methods/vars in `lowerCamelCase`.
- Keep UI in `whisperswift/UI/` and service logic in `whisperswift/Services/`.
- Prefer small, focused types; keep side effects (permissions, audio, hotkeys) in services.

## Testing Guidelines
- No test target is present yet. If adding tests, use XCTest and place files under a `whisperswiftTests/` target.
- Name test files `SomethingTests.swift` and test methods `testSomethingBehavior()`.

## Commit & Pull Request Guidelines
- Commit history uses short, imperative messages (e.g. "Fix build errors", "Add Groq API integration"). Keep subject lines concise.
- PRs should describe user-visible changes, include reproduction steps, and mention permission impacts (microphone/accessibility) if relevant.

## Security & Configuration Notes
- Entitlements live in `whisperswift/whisperswift.entitlements`. Update carefully when adding capabilities.
- Model files are local-only; do not add network calls or telemetry without explicit discussion.
