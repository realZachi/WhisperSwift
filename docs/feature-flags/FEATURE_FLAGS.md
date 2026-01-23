# Feature Flags

This document describes the feature flag infrastructure in WhisperSwift, how to use it, and guidelines for adding new feature flags.

## Overview

Feature flags allow for progressive rollouts, A/B testing, and runtime configuration of application behavior without requiring app updates. The WhisperSwift feature flag system provides:

- **Type-safe flags**: Boolean, string, integer, and double value types
- **Default values**: Each flag has a sensible default
- **Persistent storage**: Values persist across app launches via UserDefaults
- **Thread-safe access**: Uses Swift actors for safe concurrent access
- **Debug tools**: Built-in utilities for testing and debugging

## Architecture

```
whisperswift/
├── FeatureFlags.swift              # Flag definitions and metadata
└── Services/
    └── FeatureFlagService.swift    # Service protocol and implementation
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `FeatureFlag` | Enum defining all available flags with defaults and documentation |
| `FeatureFlagValue` | Type-safe wrapper for flag values |
| `FeatureFlagProvider` | Protocol for flag providers (local, remote, etc.) |
| `LocalFeatureFlagService` | UserDefaults-based implementation |

## Usage

### Checking Boolean Flags

```swift
// Using global convenience function (recommended for simple checks)
if isFeatureEnabled(.experimentalTranscriptionCleanup) {
    // Use experimental cleanup
}

// Using the service directly
let flagService = LocalFeatureFlagService.shared
if flagService.isEnabled(.experimentalTranscriptionCleanup) {
    // Use experimental cleanup
}
```

### Getting Typed Values

```swift
// String values
let model = featureFlagString(.customModelName)

// Integer values
let maxRetries = featureFlagInt(.apiMaxRetries)

// Double values
let timeout = featureFlagDouble(.apiTimeoutSeconds)

// Using the service directly (within async context)
let timeout = await LocalFeatureFlagService.shared.double(for: .apiTimeoutSeconds)
```

### Setting Values Programmatically

```swift
// Must be called within async context due to actor isolation
Task {
    await LocalFeatureFlagService.shared.setValue(.boolean(true), for: .debugOverlay)
    await LocalFeatureFlagService.shared.setValue(.integer(5), for: .apiMaxRetries)
}
```

### Resetting Flags

```swift
Task {
    // Reset a single flag to its default
    await LocalFeatureFlagService.shared.resetToDefault(.debugOverlay)

    // Reset all flags to defaults
    await LocalFeatureFlagService.shared.resetAllToDefaults()
}
```

## Adding New Feature Flags

### Step 1: Define the Flag

Add a new case to the `FeatureFlag` enum in `FeatureFlags.swift`:

```swift
enum FeatureFlag: String, CaseIterable {
    // ... existing flags ...

    /// Brief description of what this flag controls.
    case myNewFeature = "my_new_feature"
}
```

### Step 2: Set the Default Value

Add the default value in the `defaultValue` computed property:

```swift
extension FeatureFlag {
    var defaultValue: FeatureFlagValue {
        switch self {
        // ... existing cases ...
        case .myNewFeature:
            return .boolean(false)  // or .string("value"), .integer(10), .double(1.5)
        }
    }
}
```

### Step 3: Add Documentation

Add a description in the `description` computed property:

```swift
extension FeatureFlag {
    var description: String {
        switch self {
        // ... existing cases ...
        case .myNewFeature:
            return "Enables the new feature that does X, Y, and Z."
        }
    }
}
```

### Step 4: Assign a Category

Add the flag to the appropriate category in the `category` computed property:

```swift
extension FeatureFlag {
    var category: FeatureFlagCategory {
        switch self {
        // ... existing cases ...
        case .myNewFeature:
            return .transcription  // or .audio, .ui, .network, .developer, .accessibility
        }
    }
}
```

### Step 5: Use the Flag

```swift
if isFeatureEnabled(.myNewFeature) {
    // New behavior
} else {
    // Existing behavior
}
```

## Testing with Feature Flags

### In Unit Tests

```swift
import XCTest

class MyFeatureTests: XCTestCase {
    var flagService: LocalFeatureFlagService!

    override func setUp() {
        // Use a separate UserDefaults suite for testing
        let testDefaults = UserDefaults(suiteName: "TestSuite")!
        flagService = LocalFeatureFlagService(userDefaults: testDefaults)
    }

    override func tearDown() async throws {
        await flagService.resetAllToDefaults()
    }

    func testFeatureEnabled() async {
        // Enable the flag
        await flagService.setValue(.boolean(true), for: .experimentalTranscriptionCleanup)

        // Test with flag enabled
        XCTAssertTrue(flagService.isEnabled(.experimentalTranscriptionCleanup))
    }

    func testFeatureDisabled() async {
        // Ensure flag is at default (disabled)
        await flagService.resetToDefault(.experimentalTranscriptionCleanup)

        // Test with flag disabled
        XCTAssertFalse(flagService.isEnabled(.experimentalTranscriptionCleanup))
    }
}
```

### Debug Testing (DEBUG builds only)

```swift
#if DEBUG
Task {
    let flagService = LocalFeatureFlagService.shared

    // Enable for testing
    await flagService.enableForTesting(.debugOverlay)

    // Get debug info
    let debugInfo = await flagService.debugDescription()
    print(debugInfo)

    // Clean up after testing
    await flagService.resetAllToDefaults()
}
#endif
```

### Manual Testing via Terminal

You can override feature flags using the `defaults` command:

```bash
# Enable a boolean flag
defaults write com.realzachi.whisperswift whisperswift.featureflag.debug_overlay -bool true

# Set an integer flag
defaults write com.realzachi.whisperswift whisperswift.featureflag.api_max_retries -int 5

# Set a double flag
defaults write com.realzachi.whisperswift whisperswift.featureflag.api_timeout_seconds -float 60.0

# Reset a flag (removes override, uses default)
defaults delete com.realzachi.whisperswift whisperswift.featureflag.debug_overlay

# Read current value
defaults read com.realzachi.whisperswift whisperswift.featureflag.debug_overlay
```

## Best Practices

### Naming Conventions

- Use `snake_case` for raw values (e.g., `experimental_transcription_cleanup`)
- Use `lowerCamelCase` for Swift enum cases (e.g., `experimentalTranscriptionCleanup`)
- Be descriptive but concise
- Prefix experimental features with `experimental_`

### Flag Lifecycle

1. **Creation**: Add flag with `false` default for new features
2. **Rollout**: Gradually enable for users (via remote config in future)
3. **Stabilization**: Once stable, consider making the feature permanent
4. **Cleanup**: Remove the flag and associated conditional code

### Code Organization

```swift
// Good: Guard clause at the start
func processTranscription(_ text: String) -> String {
    guard isFeatureEnabled(.experimentalTranscriptionCleanup) else {
        return text
    }
    return performExperimentalCleanup(text)
}

// Good: Clear feature boundaries
func insertText(_ text: String) {
    if isFeatureEnabled(.alternativeTextInsertion) {
        insertViaAlternativeMethod(text)
    } else {
        insertViaStandardMethod(text)
    }
}

// Avoid: Deeply nested flag checks
func complexOperation() {
    if isFeatureEnabled(.flagA) {
        if isFeatureEnabled(.flagB) {
            // This is hard to reason about
        }
    }
}
```

### Documentation

- Always provide a description for each flag
- Document the expected behavior when enabled vs disabled
- Note any dependencies on other flags
- Update this document when adding significant flags

## Future: Remote Configuration

The `FeatureFlagProvider` protocol is designed to support remote configuration services. Future integrations may include:

- **Firebase Remote Config**: Google's remote configuration service
- **LaunchDarkly**: Feature management platform
- **Custom Backend**: Your own feature flag service

Example remote provider implementation:

```swift
actor RemoteFeatureFlagService: FeatureFlagProvider {
    private let remoteConfig: RemoteConfigClient
    private let fallback: LocalFeatureFlagService

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        // Try remote first, fall back to local
        if let remoteValue = remoteConfig.getBool(flag.rawValue) {
            return remoteValue
        }
        return fallback.isEnabled(flag)
    }

    // ... implement other protocol methods
}
```

## Current Feature Flags

| Flag | Category | Default | Description |
|------|----------|---------|-------------|
| `experimentalTranscriptionCleanup` | Transcription | `false` | Enhanced AI cleanup for transcriptions |
| `verboseTranscriptionLogging` | Transcription | `false` | Detailed transcription logging |
| `enhancedAudioNormalization` | Audio | `false` | Improved audio normalization |
| `audioLevelVisualization` | Audio | `true` | Real-time audio level display |
| `newRecordingPillDesign` | UI | `false` | New pill design with animations |
| `hapticFeedback` | UI | `false` | Haptic feedback (future) |
| `forceDarkMode` | UI | `false` | Force dark appearance |
| `apiMaxRetries` | Network | `3` | Max API retry attempts |
| `apiTimeoutSeconds` | Network | `30.0` | API request timeout |
| `enableRequestCompression` | Network | `false` | Compress API requests |
| `debugOverlay` | Developer | `false` | Debug state overlay |
| `performanceMetrics` | Developer | `false` | Performance logging |
| `mockTranscriptionService` | Developer | `false` | Mock API responses |
| `enhancedAccessibilityAnnouncements` | Accessibility | `false` | Enhanced VoiceOver |
| `alternativeTextInsertion` | Accessibility | `false` | Alternative text insertion |

## Dead Flag Detection

The project includes automated tooling to detect potentially unused feature flags.

### Running Locally

```bash
./scripts/detect-dead-flags.sh
```

### CI Integration

Dead flag detection runs automatically:
- On every push to `main` that modifies feature flag files
- On every PR that touches Swift files
- Weekly on Mondays (scheduled)

The workflow generates a report and comments on PRs when dead flags are detected.

### What Counts as "Dead"

A flag is considered potentially dead if:
- No `.flagName` usage exists outside `FeatureFlags.swift`
- No usage in production code (test files are excluded)

Flags may appear dead but still be valid if:
- Accessed via string `rawValue`
- Used only in debug/test configurations
- Recently added and pending integration

### Removing Dead Flags

1. Verify the flag is truly unused (check tests, debug code)
2. Remove the `case` from `FeatureFlag` enum
3. Remove corresponding `defaultValue`, `description`, and `category` entries
4. Search for any string-based references to the raw value
5. Run tests to ensure nothing breaks

## Troubleshooting

### Flag Not Taking Effect

1. Ensure the flag is being checked in the correct code path
2. Verify the flag value with debug description:
   ```swift
   #if DEBUG
   Task {
       print(await LocalFeatureFlagService.shared.debugDescription())
   }
   #endif
   ```
3. Check if the value was overridden via `defaults` command

### Performance Concerns

- Reads go directly to UserDefaults, which is optimized by the system
- For hot paths, consider caching the flag value locally

### Thread Safety

- `LocalFeatureFlagService` is an actor with `nonisolated(unsafe)` UserDefaults access
- UserDefaults is thread-safe, allowing synchronous access from any context
- Value types (enums, structs) ensure data safety
