# Repository Guidelines

## Project Structure & Module Organization
- `localwhisper/` holds the Swift app sources.
  - `localwhisper/UI/` contains SwiftUI views (menu bar, settings).
  - `localwhisper/Services/` contains app services (audio capture, hotkeys, permissions, whisper inference).
  - `localwhisper/Assets.xcassets/` contains icons and color assets.
- Models are downloaded at runtime and stored under the app support directory (no bundled model binaries).
- `localwhisper.xcodeproj/` is the Xcode project definition.

## Build, Test, and Development Commands
- Open in Xcode: `open localwhisper.xcodeproj` (recommended for running the menu bar app).
- Build from CLI: `xcodebuild -project localwhisper.xcodeproj -scheme localwhisper -configuration Debug build`.
- Run via Xcode for menu bar behavior and permissions prompts.

## Coding Style & Naming Conventions
- Swift style: 4-space indentation; types in `UpperCamelCase`, methods/vars in `lowerCamelCase`.
- Keep UI in `localwhisper/UI/` and service logic in `localwhisper/Services/`.
- Prefer small, focused types; keep side effects (permissions, audio, hotkeys) in services.

## Testing Guidelines
- No test target is present yet. If adding tests, use XCTest and place files under a `localwhisperTests/` target.
- Name test files `SomethingTests.swift` and test methods `testSomethingBehavior()`.

## Commit & Pull Request Guidelines
- Commit history uses short, imperative messages (e.g. "Fix build errors", "Add WhisperKit integration"). Keep subject lines concise.
- PRs should describe user-visible changes, include reproduction steps, and mention permission impacts (microphone/accessibility) if relevant.

## Security & Configuration Notes
- Entitlements live in `localwhisper/localwhisper.entitlements`. Update carefully when adding capabilities.
- Model files are local-only; do not add network calls or telemetry without explicit discussion.
