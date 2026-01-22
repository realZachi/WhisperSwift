//
//  FeatureFlags.swift
//  whisperswift
//
//  Defines all feature flags used in the application.
//  Each flag has a unique identifier, default value, and documentation.
//

import Foundation

/// Enumeration of all feature flags in the application.
/// Each case represents a configurable feature or behavior.
///
/// To add a new feature flag:
/// 1. Add a new case to this enum
/// 2. Provide a default value in the `defaultValue` computed property
/// 3. Add documentation in the `description` computed property
/// 4. Use the flag in code via `isFeatureEnabled(.yourFlag)` or the FeatureFlagService
///
/// Example usage:
/// ```swift
/// // Boolean flag check
/// if isFeatureEnabled(.experimentalTranscriptionCleanup) {
///     // Use experimental cleanup
/// }
///
/// // Numeric flag for configuration
/// let timeout = featureFlagDouble(.apiTimeoutSeconds)
/// ```
enum FeatureFlag: String, CaseIterable {
    // MARK: - Transcription Features

    /// Enables experimental transcription cleanup using enhanced AI processing.
    /// When enabled, transcriptions go through an additional cleanup pass
    /// to remove disfluencies and improve readability.
    case experimentalTranscriptionCleanup = "experimental_transcription_cleanup"

    /// Enables verbose logging of transcription operations.
    /// Useful for debugging transcription issues.
    case verboseTranscriptionLogging = "verbose_transcription_logging"

    // MARK: - Audio Features

    /// Enables enhanced audio normalization before transcription.
    /// May improve transcription accuracy in noisy environments.
    case enhancedAudioNormalization = "enhanced_audio_normalization"

    /// Enables audio level visualization in the recording pill.
    /// Shows real-time audio levels during recording.
    case audioLevelVisualization = "audio_level_visualization"

    // MARK: - UI Features

    /// Enables the new recording pill design with enhanced animations.
    case newRecordingPillDesign = "new_recording_pill_design"

    /// Enables haptic feedback on supported devices.
    /// Currently no-op on macOS but prepared for future support.
    case hapticFeedback = "haptic_feedback"

    /// Enables dark mode support independent of system setting.
    case forceDarkMode = "force_dark_mode"

    // MARK: - Network & API Features

    /// Maximum number of retry attempts for API requests.
    case apiMaxRetries = "api_max_retries"

    /// Timeout in seconds for API requests.
    case apiTimeoutSeconds = "api_timeout_seconds"

    /// Enables request compression for API calls.
    /// May reduce bandwidth usage but increase CPU load.
    case enableRequestCompression = "enable_request_compression"

    // MARK: - Developer & Debug Features

    /// Enables debug overlay showing internal state.
    /// Only available in DEBUG builds.
    case debugOverlay = "debug_overlay"

    /// Enables performance metrics logging.
    case performanceMetrics = "performance_metrics"

    /// Mock transcription service for testing without API calls.
    /// When enabled, returns predefined test responses.
    case mockTranscriptionService = "mock_transcription_service"

    // MARK: - Accessibility Features

    /// Enables enhanced accessibility announcements for VoiceOver.
    case enhancedAccessibilityAnnouncements = "enhanced_accessibility_announcements"

    /// Uses alternative text insertion method for specific apps.
    case alternativeTextInsertion = "alternative_text_insertion"
}

// MARK: - Default Values

extension FeatureFlag {
    /// Returns the default value for this feature flag.
    /// These defaults are used when no override has been set.
    var defaultValue: FeatureFlagValue {
        switch self {
        // Transcription Features
        case .experimentalTranscriptionCleanup:
            return .boolean(false)
        case .verboseTranscriptionLogging:
            return .boolean(false)

        // Audio Features
        case .enhancedAudioNormalization:
            return .boolean(false)
        case .audioLevelVisualization:
            return .boolean(true)

        // UI Features
        case .newRecordingPillDesign:
            return .boolean(false)
        case .hapticFeedback:
            return .boolean(false)
        case .forceDarkMode:
            return .boolean(false)

        // Network & API Features
        case .apiMaxRetries:
            return .integer(3)
        case .apiTimeoutSeconds:
            return .double(30.0)
        case .enableRequestCompression:
            return .boolean(false)

        // Developer & Debug Features
        case .debugOverlay:
            return .boolean(false)
        case .performanceMetrics:
            return .boolean(false)
        case .mockTranscriptionService:
            return .boolean(false)

        // Accessibility Features
        case .enhancedAccessibilityAnnouncements:
            return .boolean(false)
        case .alternativeTextInsertion:
            return .boolean(false)
        }
    }
}

// MARK: - Documentation

extension FeatureFlag {
    /// Returns a human-readable description of this feature flag.
    var description: String {
        switch self {
        // Transcription Features
        case .experimentalTranscriptionCleanup:
            return "Enables experimental transcription cleanup using enhanced AI processing to remove disfluencies and improve readability."
        case .verboseTranscriptionLogging:
            return "Enables detailed logging of transcription operations for debugging purposes."

        // Audio Features
        case .enhancedAudioNormalization:
            return "Applies enhanced audio normalization before transcription, which may improve accuracy in noisy environments."
        case .audioLevelVisualization:
            return "Shows real-time audio level visualization in the recording pill during recording."

        // UI Features
        case .newRecordingPillDesign:
            return "Enables the new recording pill design with enhanced animations and visual feedback."
        case .hapticFeedback:
            return "Enables haptic feedback for recording start/stop events (prepared for future macOS support)."
        case .forceDarkMode:
            return "Forces dark mode appearance regardless of system setting."

        // Network & API Features
        case .apiMaxRetries:
            return "Maximum number of retry attempts for failed API requests before giving up."
        case .apiTimeoutSeconds:
            return "Timeout duration in seconds for API requests."
        case .enableRequestCompression:
            return "Enables compression of API request payloads to reduce bandwidth usage."

        // Developer & Debug Features
        case .debugOverlay:
            return "Shows a debug overlay with internal state information (DEBUG builds only)."
        case .performanceMetrics:
            return "Enables logging of performance metrics for monitoring and optimization."
        case .mockTranscriptionService:
            return "Uses mock transcription responses for testing without making actual API calls."

        // Accessibility Features
        case .enhancedAccessibilityAnnouncements:
            return "Provides enhanced VoiceOver announcements for better accessibility."
        case .alternativeTextInsertion:
            return "Uses an alternative text insertion method that may work better with specific applications."
        }
    }

    /// Returns the category this feature flag belongs to.
    var category: FeatureFlagCategory {
        switch self {
        case .experimentalTranscriptionCleanup, .verboseTranscriptionLogging:
            return .transcription
        case .enhancedAudioNormalization, .audioLevelVisualization:
            return .audio
        case .newRecordingPillDesign, .hapticFeedback, .forceDarkMode:
            return .ui
        case .apiMaxRetries, .apiTimeoutSeconds, .enableRequestCompression:
            return .network
        case .debugOverlay, .performanceMetrics, .mockTranscriptionService:
            return .developer
        case .enhancedAccessibilityAnnouncements, .alternativeTextInsertion:
            return .accessibility
        }
    }
}

// MARK: - Feature Flag Categories

/// Categories for organizing feature flags.
enum FeatureFlagCategory: String, CaseIterable {
    case transcription = "Transcription"
    case audio = "Audio"
    case ui = "User Interface"
    case network = "Network & API"
    case developer = "Developer & Debug"
    case accessibility = "Accessibility"

    /// Returns all feature flags in this category.
    var flags: [FeatureFlag] {
        FeatureFlag.allCases.filter { $0.category == self }
    }
}
