//
//  AnalyticsService.swift
//  whisperswift
//
//  Privacy-respecting analytics service for product insights.
//  Provides event tracking with a focus on user privacy.
//
//  ## Privacy Principles
//
//  This service is designed with privacy as a core principle:
//  - No personal data collection by default
//  - No audio content or transcription text is tracked
//  - Events are anonymized and aggregated locally
//  - User consent is required before any external transmission
//  - All data can be viewed, exported, and deleted by the user
//
//  ## Integration with External Analytics
//
//  To integrate with external analytics services (e.g., PostHog, Amplitude, Mixpanel):
//
//  1. Implement the AnalyticsProviderProtocol:
//     ```swift
//     class PostHogProvider: AnalyticsProviderProtocol {
//         func trackEvent(_ event: AnalyticsEvent) async {
//             // Convert to PostHog format and send
//             PHGPostHog.shared()?.capture(
//                 event.name,
//                 properties: event.properties
//             )
//         }
//
//         func identify(userId: String, traits: [String: Any]) async {
//             PHGPostHog.shared()?.identify(userId, properties: traits)
//         }
//
//         func reset() async {
//             PHGPostHog.shared()?.reset()
//         }
//
//         func flush() async {
//             PHGPostHog.shared()?.flush()
//         }
//     }
//     ```
//
//  2. Register the provider after user consent:
//     ```swift
//     if userHasConsented {
//         await AnalyticsService.shared.addProvider(PostHogProvider())
//     }
//     ```
//
//  3. Events will be sent to all registered providers.
//

import Foundation

/// Represents an analytics event.
struct AnalyticsEvent: Sendable {
    let id: String
    let name: String
    let timestamp: Date
    let properties: [String: String]
    let sessionId: String

    init(name: String, properties: [String: String] = [:], sessionId: String) {
        self.id = UUID().uuidString
        self.name = name
        self.timestamp = Date()
        self.properties = properties
        self.sessionId = sessionId
    }
}

/// Protocol for analytics provider implementations.
protocol AnalyticsProviderProtocol: Sendable {
    /// Tracks an event.
    func trackEvent(_ event: AnalyticsEvent) async

    /// Identifies a user (optional, may be no-op for privacy-focused providers).
    func identify(userId: String, traits: [String: String]) async

    /// Resets the current user/session.
    func reset() async

    /// Flushes any pending events.
    func flush() async
}

/// Local analytics provider that stores events locally.
/// Privacy-respecting: no data leaves the device.
final class LocalAnalyticsProvider: AnalyticsProviderProtocol, @unchecked Sendable {
    private var events: [AnalyticsEvent] = []
    private let maxEvents = 10000
    private let lock = NSLock()

    func trackEvent(_ event: AnalyticsEvent) async {
        lock.lock()
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        lock.unlock()

        logToFile("[ANALYTICS] Event: \(event.name) \(formatProperties(event.properties))")
    }

    func identify(userId: String, traits: [String: String]) async {
        // Local provider doesn't track user identity for privacy
        logToFile("[ANALYTICS] Identify called (no-op for local provider)")
    }

    func reset() async {
        lock.lock()
        events.removeAll()
        lock.unlock()
        logToFile("[ANALYTICS] Reset - all events cleared")
    }

    func flush() async {
        // Local provider doesn't need to flush
        logToFile("[ANALYTICS] Flush called (no-op for local provider)")
    }

    /// Returns all stored events.
    func getEvents() -> [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    /// Returns events filtered by name.
    func getEvents(named name: String) -> [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events.filter { $0.name == name }
    }

    /// Returns event counts grouped by name.
    func getEventCounts() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return Dictionary(grouping: events) { $0.name }
            .mapValues { $0.count }
    }

    /// Returns events within a time range.
    func getEvents(from startDate: Date, to endDate: Date) -> [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Exports events as JSON data.
    func exportEvents() -> Data? {
        lock.lock()
        let eventDicts = events.map { event -> [String: Any] in
            [
                "id": event.id,
                "name": event.name,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                "properties": event.properties,
                "sessionId": event.sessionId
            ]
        }
        lock.unlock()

        return try? JSONSerialization.data(withJSONObject: eventDicts, options: .prettyPrinted)
    }

    private func formatProperties(_ props: [String: String]) -> String {
        if props.isEmpty { return "" }
        let formatted = props.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return "{\(formatted)}"
    }
}

/// Thread-safe analytics service for product insights.
/// Supports multiple providers and respects user privacy.
actor AnalyticsService {
    /// Shared singleton instance
    static let shared = AnalyticsService()

    /// Whether analytics is enabled
    private var isEnabled: Bool = true

    /// Whether user has consented to analytics
    private var hasConsent: Bool = false

    /// Current session ID
    private var sessionId: String

    /// Session start time
    private let sessionStartTime: Date

    /// Registered analytics providers
    private var providers: [any AnalyticsProviderProtocol] = []

    /// Local provider (always available)
    private let localProvider = LocalAnalyticsProvider()

    /// Global properties added to all events
    private var globalProperties: [String: String] = [:]

    /// Super properties (persistent across sessions)
    private var superProperties: [String: String] = [:]

    private init() {
        self.sessionId = UUID().uuidString
        self.sessionStartTime = Date()

        // Register local provider by default
        providers.append(localProvider)

        // Load super properties from UserDefaults
        if let saved = UserDefaults.standard.dictionary(forKey: "analyticsService.superProperties") as? [String: String] {
            superProperties = saved
        }

        // Set default global properties
        globalProperties["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        globalProperties["os_version"] = ProcessInfo.processInfo.operatingSystemVersionString
    }

    // MARK: - Configuration

    /// Enables or disables analytics.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        logToFile("[ANALYTICS] Analytics \(enabled ? "enabled" : "disabled")")
    }

    /// Returns whether analytics is enabled.
    func getEnabled() -> Bool {
        return isEnabled
    }

    /// Sets user consent for analytics.
    /// External providers are only used when consent is given.
    func setConsent(_ consent: Bool) {
        hasConsent = consent
        logToFile("[ANALYTICS] Consent \(consent ? "granted" : "revoked")")

        if !consent {
            // Remove external providers when consent is revoked
            providers = providers.filter { $0 is LocalAnalyticsProvider }
        }
    }

    /// Returns whether user has consented to analytics.
    func getConsent() -> Bool {
        return hasConsent
    }

    /// Adds an analytics provider (requires consent for external providers).
    func addProvider(_ provider: any AnalyticsProviderProtocol) {
        if provider is LocalAnalyticsProvider {
            return // Local provider is always registered
        }

        guard hasConsent else {
            logToFile("[ANALYTICS] Cannot add external provider without consent")
            return
        }

        providers.append(provider)
        logToFile("[ANALYTICS] Added external provider")
    }

    /// Removes all external providers.
    func removeExternalProviders() {
        providers = providers.filter { $0 is LocalAnalyticsProvider }
        logToFile("[ANALYTICS] Removed all external providers")
    }

    // MARK: - Properties

    /// Sets a global property added to all events.
    func setGlobalProperty(key: String, value: String) {
        globalProperties[key] = value
    }

    /// Sets a super property (persisted across sessions).
    func setSuperProperty(key: String, value: String) {
        superProperties[key] = value
        saveSuperProperties()
    }

    /// Removes a super property.
    func removeSuperProperty(key: String) {
        superProperties.removeValue(forKey: key)
        saveSuperProperties()
    }

    /// Clears all super properties.
    func clearSuperProperties() {
        superProperties.removeAll()
        saveSuperProperties()
    }

    private func saveSuperProperties() {
        UserDefaults.standard.set(superProperties, forKey: "analyticsService.superProperties")
    }

    // MARK: - Event Tracking

    /// Tracks an event with optional properties.
    func track(_ eventName: String, properties: [String: String] = [:]) async {
        guard isEnabled else { return }

        var mergedProperties = globalProperties
        for (key, value) in superProperties {
            mergedProperties[key] = value
        }
        for (key, value) in properties {
            mergedProperties[key] = value
        }

        let event = AnalyticsEvent(
            name: eventName,
            properties: mergedProperties,
            sessionId: sessionId
        )

        // Send to all providers
        for provider in providers {
            // Only send to external providers if consent is given
            if provider is LocalAnalyticsProvider || hasConsent {
                await provider.trackEvent(event)
            }
        }
    }

    // MARK: - Convenience Methods for WhisperSwift Events

    /// Tracks app launch.
    func trackAppLaunched() async {
        await track("app_launched", properties: [
            "launch_time": ISO8601DateFormatter().string(from: sessionStartTime)
        ])
    }

    /// Tracks app termination.
    func trackAppTerminated() async {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        await track("app_terminated", properties: [
            "session_duration_seconds": String(format: "%.0f", sessionDuration)
        ])
    }

    /// Tracks recording started.
    func trackRecordingStarted() async {
        await track("recording_started")
    }

    /// Tracks recording completed.
    func trackRecordingCompleted(durationSeconds: Double) async {
        // Note: We only track duration ranges to preserve privacy
        let durationBucket = bucketize(durationSeconds, buckets: [1, 5, 10, 30, 60, 120])
        await track("recording_completed", properties: [
            "duration_bucket": durationBucket
        ])
    }

    /// Tracks recording cancelled.
    func trackRecordingCancelled() async {
        await track("recording_cancelled")
    }

    /// Tracks transcription completed.
    func trackTranscriptionCompleted(latencyMs: Double, success: Bool) async {
        // Bucket latency to preserve privacy
        let latencyBucket = bucketize(latencyMs, buckets: [100, 250, 500, 1000, 2500, 5000])
        await track("transcription_completed", properties: [
            "success": String(success),
            "latency_bucket": latencyBucket
        ])
    }

    /// Tracks text insertion.
    func trackTextInserted(method: String) async {
        await track("text_inserted", properties: [
            "method": method
        ])
    }

    /// Tracks settings changed.
    func trackSettingsChanged(setting: String) async {
        await track("settings_changed", properties: [
            "setting": setting
        ])
    }

    /// Tracks feature used.
    func trackFeatureUsed(_ feature: String) async {
        await track("feature_used", properties: [
            "feature": feature
        ])
    }

    // MARK: - Session Management

    /// Starts a new session.
    func startNewSession() {
        sessionId = UUID().uuidString
        logToFile("[ANALYTICS] New session started: \(sessionId.prefix(8))")
    }

    /// Returns the current session ID.
    func getSessionId() -> String {
        return sessionId
    }

    // MARK: - User Management

    /// Identifies a user (only with consent).
    func identify(userId: String, traits: [String: String] = [:]) async {
        guard isEnabled && hasConsent else { return }

        for provider in providers {
            await provider.identify(userId: userId, traits: traits)
        }
    }

    /// Resets the current user/session.
    func reset() async {
        startNewSession()

        for provider in providers {
            await provider.reset()
        }
    }

    // MARK: - Data Access

    /// Returns the local analytics provider for data access.
    func getLocalProvider() -> LocalAnalyticsProvider {
        return localProvider
    }

    /// Returns a summary of analytics data.
    func getSummary() -> AnalyticsSummary {
        let events = localProvider.getEvents()
        let counts = localProvider.getEventCounts()

        return AnalyticsSummary(
            sessionId: sessionId,
            sessionStartTime: sessionStartTime,
            totalEvents: events.count,
            eventCounts: counts,
            hasConsent: hasConsent,
            externalProvidersCount: providers.count - 1 // Exclude local provider
        )
    }

    /// Exports all analytics data as JSON.
    func exportData() -> Data? {
        return localProvider.exportEvents()
    }

    /// Deletes all analytics data.
    func deleteAllData() async {
        await localProvider.reset()
        clearSuperProperties()
        logToFile("[ANALYTICS] All analytics data deleted")
    }

    // MARK: - Flush

    /// Flushes all pending events to providers.
    func flush() async {
        for provider in providers {
            await provider.flush()
        }
    }

    // MARK: - Helpers

    private func bucketize(_ value: Double, buckets: [Double]) -> String {
        for bucket in buckets {
            if value <= bucket {
                return "<=\(Int(bucket))"
            }
        }
        return ">\(Int(buckets.last ?? 0))"
    }
}

// MARK: - Supporting Types

/// Summary of analytics data.
struct AnalyticsSummary: Sendable {
    let sessionId: String
    let sessionStartTime: Date
    let totalEvents: Int
    let eventCounts: [String: Int]
    let hasConsent: Bool
    let externalProvidersCount: Int

    var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStartTime)
    }

    var formattedSessionDuration: String {
        let hours = Int(sessionDuration) / 3600
        let minutes = (Int(sessionDuration) % 3600) / 60
        let seconds = Int(sessionDuration) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
