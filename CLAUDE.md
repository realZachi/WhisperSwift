# CLAUDE.md

Native macOS menu bar app for speech-to-text via Groq API. Hold hotkey, speak, release, text appears.

- **Platform**: macOS 13.0+, Apple Silicon
- **Language**: Swift 5.0, SwiftUI

## Commands

```bash
# Build (run after code changes)
xcodebuild -project whisperswift.xcodeproj -scheme whisperswift -configuration Debug build

# Test
xcodebuild test -project whisperswift.xcodeproj -scheme whisperswift -destination 'platform=macOS'

# Build with timing analysis
./scripts/build-with-timing.sh

# Code quality
./scripts/check-duplicates.sh    # Duplication check
./scripts/generate-docs.sh       # API docs
```

## Git Workflow

**IMPORTANT**: Create a feature branch before making changes: `git checkout -b feature/<name>`

## Critical Notes

- **Auto-build**: After Swift file changes, always run the build command above
- **Sandbox disabled**: Required for global hotkeys and accessibility API
- **Entitlements**: Edit `whisperswift/whisperswift.entitlements` carefully
- **Debug logs**: Written to `/tmp/whisperswift.log`

## Guidelines

For specific tasks, read the relevant documentation:

| Task | Read First |
|------|------------|
| Understanding codebase | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Build performance issues | [docs/BUILD_PERFORMANCE.md](docs/BUILD_PERFORMANCE.md) |
| Feature flag changes | [docs/feature-flags/FEATURE_FLAGS.md](docs/feature-flags/FEATURE_FLAGS.md) |
| Code style questions | [docs/CODE_STYLE.md](docs/CODE_STYLE.md) |
| Observability/tracing | [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md) |
| CI/CD workflows | [docs/CI_CD.md](docs/CI_CD.md) |
| Release/DMG creation | [docs/RELEASE_BUILD.md](docs/RELEASE_BUILD.md) |
| Alerting setup | [docs/alerting/ALERTING.md](docs/alerting/ALERTING.md) |
