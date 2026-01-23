//
//  FeatureFlagService.swift
//  whisperswift
//

import Foundation

// MARK: - Feature Flag Value Types

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

protocol FeatureFlagProvider: Sendable {
    func value(for flag: FeatureFlag) -> FeatureFlagValue?
    func setValue(_ value: FeatureFlagValue, for flag: FeatureFlag)
    func resetToDefault(_ flag: FeatureFlag)
    func resetAllToDefaults()
    func isEnabled(_ flag: FeatureFlag) -> Bool
    func string(for flag: FeatureFlag) -> String
    func integer(for flag: FeatureFlag) -> Int
    func double(for flag: FeatureFlag) -> Double
}

// MARK: - Local Feature Flag Service

actor LocalFeatureFlagService: FeatureFlagProvider {
    static let shared = LocalFeatureFlagService()

    private nonisolated(unsafe) let userDefaults: UserDefaults
    private let keyPrefix = "whisperswift.featureflag."

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

    nonisolated func setValue(_ value: FeatureFlagValue, for flag: FeatureFlag) {
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

    nonisolated func resetToDefault(_ flag: FeatureFlag) {
        let key = keyPrefix + flag.rawValue
        userDefaults.removeObject(forKey: key)
        logToFile("Feature flag '\(flag.rawValue)' reset to default")
    }

    nonisolated func resetAllToDefaults() {
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

    func allValues() -> [FeatureFlag: FeatureFlagValue] {
        var result: [FeatureFlag: FeatureFlagValue] = [:]
        for flag in FeatureFlag.allCases {
            result[flag] = value(for: flag) ?? flag.defaultValue
        }
        return result
    }

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

// MARK: - Debug

#if DEBUG
extension LocalFeatureFlagService {
    func enableForTesting(_ flag: FeatureFlag) {
        setValue(.boolean(true), for: flag)
    }

    func disableForTesting(_ flag: FeatureFlag) {
        setValue(.boolean(false), for: flag)
    }

    func setTestValue(_ value: FeatureFlagValue, for flag: FeatureFlag) {
        setValue(value, for: flag)
    }

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

nonisolated func isFeatureEnabled(_ flag: FeatureFlag) -> Bool {
    LocalFeatureFlagService.shared.isEnabled(flag)
}

nonisolated func featureFlagString(_ flag: FeatureFlag) -> String {
    LocalFeatureFlagService.shared.string(for: flag)
}

nonisolated func featureFlagInt(_ flag: FeatureFlag) -> Int {
    LocalFeatureFlagService.shared.integer(for: flag)
}

nonisolated func featureFlagDouble(_ flag: FeatureFlag) -> Double {
    LocalFeatureFlagService.shared.double(for: flag)
}
