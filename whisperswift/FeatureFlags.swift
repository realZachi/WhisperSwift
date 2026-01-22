//
//  FeatureFlags.swift
//  whisperswift
//

import Foundation

enum FeatureFlag: String, CaseIterable {
    // MARK: - Transcription Features
    case experimentalTranscriptionCleanup = "experimental_transcription_cleanup"
    case verboseTranscriptionLogging = "verbose_transcription_logging"

    // MARK: - Audio Features
    case enhancedAudioNormalization = "enhanced_audio_normalization"
    case audioLevelVisualization = "audio_level_visualization"

    // MARK: - UI Features
    case newRecordingPillDesign = "new_recording_pill_design"
    case hapticFeedback = "haptic_feedback"
    case forceDarkMode = "force_dark_mode"

    // MARK: - Network & API Features
    case apiMaxRetries = "api_max_retries"
    case apiTimeoutSeconds = "api_timeout_seconds"
    case enableRequestCompression = "enable_request_compression"

    // MARK: - Developer & Debug Features
    case debugOverlay = "debug_overlay"
    case performanceMetrics = "performance_metrics"
    case mockTranscriptionService = "mock_transcription_service"

    // MARK: - Accessibility Features
    case enhancedAccessibilityAnnouncements = "enhanced_accessibility_announcements"
    case alternativeTextInsertion = "alternative_text_insertion"
}

// MARK: - Default Values

extension FeatureFlag {
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

enum FeatureFlagCategory: String, CaseIterable {
    case transcription = "Transcription"
    case audio = "Audio"
    case ui = "User Interface"
    case network = "Network & API"
    case developer = "Developer & Debug"
    case accessibility = "Accessibility"

    var flags: [FeatureFlag] {
        FeatureFlag.allCases.filter { $0.category == self }
    }
}
