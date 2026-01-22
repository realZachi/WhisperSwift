//
//  FeatureFlagService.swift
//  whisperswift
//
//  Service for managing feature flags with support for boolean, string, and numeric values.
//  Provides thread-safe access to feature flag values with UserDefaults persistence.
//

import Foundation

// MARK: - Feature Flag Value Types

/// Represents the possible value types for a feature flag.
enum FeatureFlagValue: Equatable {
    case boolean(Bool)
    case string(String)
    case integer(Int)
    case double(Double)

    var boolValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }
}

// MARK: - Feature Flag Provider Protocol

/// Protocol defining the interface for feature flag management.
/// Implement this protocol to create custom feature flag providers
/// (e.g., remote config services, A/B testing platforms).
protocol FeatureFlagProvider: Sendable {
    /// Returns the current value for a feature flag, or nil if not set.
    func value(for flag: FeatureFlag) -> FeatureFlagValue?

    /// Sets a value for a feature flag.
    func setValue(_ value: FeatureFlagValue, for flag: FeatureFlag)

    /// Resets a feature flag to its default value.
    func resetToDefault(_ flag: FeatureFlag)

    /// Resets all feature flags to their default values.
    func resetAllToDefaults()

    /// Returns whether a boolean feature flag is enabled.
    /// Returns the default value if the flag is not set.
    func isEnabled(_ flag: FeatureFlag) -> Bool

    /// Returns a string feature flag value.
    /// Returns the default value if the flag is not set.
    func string(for flag: FeatureFlag) -> String

    /// Returns an integer feature flag value.
    /// Returns the default value if the flag is not set.
    func integer(for flag: FeatureFlag) -> Int

    /// Returns a double feature flag value.
    /// Returns the default value if the flag is not set.
    func double(for flag: FeatureFlag) -> Double
}

// MARK: - Local Feature Flag Service (UserDefaults-based)

/// Thread-safe feature flag service using UserDefaults for local storage.
/// This implementation provides persistent feature flag storage on the device.
///
/// Usage:
/// ```swift
/// let flagService = LocalFeatureFlagService.shared
///
/// // Check if a feature is enabled
/// if flagService.isEnabled(.experimentalTranscriptionCleanup) {
///     // Use new cleanup algorithm
/// }
///
/// // Get a numeric configuration value
/// let maxRetries = flagService.integer(for: .apiMaxRetries)
/// ```
actor LocalFeatureFlagService: FeatureFlagProvider {
    /// Shared singleton instance for app-wide feature flag access.
    static let shared = LocalFeatureFlagService()

    private let userDefaults: UserDefaults
    private let keyPrefix = "whisperswift.featureflag."

    /// Initializes the service with the specified UserDefaults instance.
    /// - Parameter userDefaults: The UserDefaults instance to use for persistence.
    ///                           Defaults to `.standard`.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - FeatureFlagProvider Implementation

    nonisolated func value(for flag: FeatureFlag) -> FeatureFlagValue? {
        let key = keyPrefix + flag.rawValue
        let defaults = userDefaults

        switch flag.defaultValue {
        case .boolean:
            if defaults.object(forKey: key) != nil {
                return .boolean(defaults.bool(forKey: key))
            }
        case .string:
            if let value = defaults.string(forKey: key) {
                return .string(value)
            }
        case .integer:
            if defaults.object(forKey: key) != nil {
                return .integer(defaults.integer(forKey: key))
            }
        case .double:
            if defaults.object(forKey: key) != nil {
                return .double(defaults.double(forKey: key))
            }
        }

        return nil
    }

    func setValue(_ value: FeatureFlagValue, for flag: FeatureFlag) {
        let key = keyPrefix + flag.rawValue

        switch value {
        case .boolean(let boolValue):
            userDefaults.set(boolValue, forKey: key)
        case .string(let stringValue):
            userDefaults.set(stringValue, forKey: key)
        case .integer(let intValue):
            userDefaults.set(intValue, forKey: key)
        case .double(let doubleValue):
            userDefaults.set(doubleValue, forKey: key)
        }

        logToFile("Feature flag '\(flag.rawValue)' set to \(value)")
    }

    func resetToDefault(_ flag: FeatureFlag) {
        let key = keyPrefix + flag.rawValue
        userDefaults.removeObject(forKey: key)
        logToFile("Feature flag '\(flag.rawValue)' reset to default")
    }

    func resetAllToDefaults() {
        for flag in FeatureFlag.allCases {
            let key = keyPrefix + flag.rawValue
            userDefaults.removeObject(forKey: key)
        }
        logToFile("All feature flags reset to defaults")
    }

    nonisolated func isEnabled(_ flag: FeatureFlag) -> Bool {
        if let value = value(for: flag) {
            if let boolValue = value.boolValue {
                return boolValue
            } else {
                logToFile("[FEATURE_FLAG] WARNING: Flag '\(flag.rawValue)' has non-boolean value: \(value), returning default")
            }
        }
        guard let defaultBool = flag.defaultValue.boolValue else {
            logToFile("[FEATURE_FLAG] ERROR: Flag '\(flag.rawValue)' default value is not boolean")
            return false
        }
        return defaultBool
    }

    nonisolated func string(for flag: FeatureFlag) -> String {
        if let value = value(for: flag) {
            if let stringValue = value.stringValue {
                return stringValue
            } else {
                logToFile("[FEATURE_FLAG] WARNING: Flag '\(flag.rawValue)' has non-string value: \(value), returning default")
            }
        }
        guard let defaultString = flag.defaultValue.stringValue else {
            logToFile("[FEATURE_FLAG] ERROR: Flag '\(flag.rawValue)' default value is not string")
            return ""
        }
        return defaultString
    }

    nonisolated func integer(for flag: FeatureFlag) -> Int {
        if let value = value(for: flag) {
            if let intValue = value.intValue {
                return intValue
            } else {
                logToFile("[FEATURE_FLAG] WARNING: Flag '\(flag.rawValue)' has non-integer value: \(value), returning default")
            }
        }
        guard let defaultInt = flag.defaultValue.intValue else {
            logToFile("[FEATURE_FLAG] ERROR: Flag '\(flag.rawValue)' default value is not integer")
            return 0
        }
        return defaultInt
    }

    nonisolated func double(for flag: FeatureFlag) -> Double {
        if let value = value(for: flag) {
            if let doubleValue = value.doubleValue {
                return doubleValue
            } else {
                logToFile("[FEATURE_FLAG] WARNING: Flag '\(flag.rawValue)' has non-double value: \(value), returning default")
            }
        }
        guard let defaultDouble = flag.defaultValue.doubleValue else {
            logToFile("[FEATURE_FLAG] ERROR: Flag '\(flag.rawValue)' default value is not double")
            return 0.0
        }
        return defaultDouble
    }

    // MARK: - Utility Methods

    /// Returns all current feature flag values (for debugging).
    func allValues() -> [FeatureFlag: FeatureFlagValue] {
        var result: [FeatureFlag: FeatureFlagValue] = [:]
        for flag in FeatureFlag.allCases {
            result[flag] = value(for: flag) ?? flag.defaultValue
        }
        return result
    }

    /// Returns all overridden feature flags (flags that differ from defaults).
    func overriddenFlags() -> [FeatureFlag: FeatureFlagValue] {
        var result: [FeatureFlag: FeatureFlagValue] = [:]
        for flag in FeatureFlag.allCases {
            if let value = value(for: flag), value != flag.defaultValue {
                result[flag] = value
            }
        }
        return result
    }
}

// MARK: - Debug UI Integration

#if DEBUG
/// Debug utilities for feature flag management during development.
extension LocalFeatureFlagService {
    /// Enables a boolean feature flag for testing.
    func enableForTesting(_ flag: FeatureFlag) {
        setValue(.boolean(true), for: flag)
    }

    /// Disables a boolean feature flag for testing.
    func disableForTesting(_ flag: FeatureFlag) {
        setValue(.boolean(false), for: flag)
    }

    /// Sets a test value for a feature flag.
    func setTestValue(_ value: FeatureFlagValue, for flag: FeatureFlag) {
        setValue(value, for: flag)
    }

    /// Returns a debug description of all feature flags and their current values.
    func debugDescription() async -> String {
        var lines: [String] = ["Feature Flags:"]
        for flag in FeatureFlag.allCases {
            let currentValue = value(for: flag) ?? flag.defaultValue
            let isOverridden = value(for: flag) != nil && value(for: flag) != flag.defaultValue
            let overrideMarker = isOverridden ? " [OVERRIDDEN]" : ""
            lines.append("  \(flag.rawValue): \(currentValue)\(overrideMarker)")
            lines.append("    Description: \(flag.description)")
        }
        return lines.joined(separator: "\n")
    }
}
#endif

// MARK: - Convenience Global Access

/// Global convenience function to check if a feature flag is enabled.
/// Uses the shared LocalFeatureFlagService instance.
///
/// Usage:
/// ```swift
/// if isFeatureEnabled(.experimentalTranscriptionCleanup) {
///     // Use experimental feature
/// }
/// ```
nonisolated func isFeatureEnabled(_ flag: FeatureFlag) -> Bool {
    LocalFeatureFlagService.shared.isEnabled(flag)
}

/// Global convenience function to get a string feature flag value.
nonisolated func featureFlagString(_ flag: FeatureFlag) -> String {
    LocalFeatureFlagService.shared.string(for: flag)
}

/// Global convenience function to get an integer feature flag value.
nonisolated func featureFlagInt(_ flag: FeatureFlag) -> Int {
    LocalFeatureFlagService.shared.integer(for: flag)
}

/// Global convenience function to get a double feature flag value.
nonisolated func featureFlagDouble(_ flag: FeatureFlag) -> Double {
    LocalFeatureFlagService.shared.double(for: flag)
}
