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
