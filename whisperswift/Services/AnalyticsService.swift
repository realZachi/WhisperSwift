//
//  AnalyticsService.swift
//  whisperswift
//

import Foundation

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

protocol AnalyticsProviderProtocol: Sendable {
    func trackEvent(_ event: AnalyticsEvent) async
    func identify(userId: String, traits: [String: String]) async
    func reset() async
    func flush() async
}

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

    func getEvents() -> [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    func getEvents(named name: String) -> [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events.filter { $0.name == name }
    }

    func getEventCounts() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return Dictionary(grouping: events) { $0.name }
            .mapValues { $0.count }
    }

    func getEvents(from startDate: Date, to endDate: Date) -> [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    func exportEvents() -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let eventDicts = events.map { event -> [String: Any] in
            [
                "id": event.id,
                "name": event.name,
                "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                "properties": event.properties,
                "sessionId": event.sessionId
            ]
        }

        do {
            return try JSONSerialization.data(withJSONObject: eventDicts, options: .prettyPrinted)
        } catch {
            logToFile("[ANALYTICS] ERROR: Failed to export events: \(error.localizedDescription)")
            return nil
        }
    }

    private func formatProperties(_ props: [String: String]) -> String {
        if props.isEmpty { return "" }
        let formatted = props.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return "{\(formatted)}"
    }
}

actor AnalyticsService {
    static let shared = AnalyticsService()

    private var isEnabled: Bool = true
    private var hasConsent: Bool = false
    private var sessionId: String
    private let sessionStartTime: Date
    private var providers: [any AnalyticsProviderProtocol] = []
    private let localProvider = LocalAnalyticsProvider()
    private var globalProperties: [String: String] = [:]
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

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        logToFile("[ANALYTICS] Analytics \(enabled ? "enabled" : "disabled")")
    }

    func getEnabled() -> Bool {
        return isEnabled
    }

    func setConsent(_ consent: Bool) {
        hasConsent = consent
        logToFile("[ANALYTICS] Consent \(consent ? "granted" : "revoked")")

        if !consent {
            // Remove external providers when consent is revoked
            providers = providers.filter { $0 is LocalAnalyticsProvider }
        }
    }

    func getConsent() -> Bool {
        return hasConsent
    }

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

    func removeExternalProviders() {
        providers = providers.filter { $0 is LocalAnalyticsProvider }
        logToFile("[ANALYTICS] Removed all external providers")
    }

    // MARK: - Properties

    func setGlobalProperty(key: String, value: String) {
        globalProperties[key] = value
    }

    func setSuperProperty(key: String, value: String) {
        superProperties[key] = value
        saveSuperProperties()
    }

    func removeSuperProperty(key: String) {
        superProperties.removeValue(forKey: key)
        saveSuperProperties()
    }

    func clearSuperProperties() {
        superProperties.removeAll()
        saveSuperProperties()
    }

    private func saveSuperProperties() {
        UserDefaults.standard.set(superProperties, forKey: "analyticsService.superProperties")
    }

    // MARK: - Event Tracking

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

    // MARK: - WhisperSwift Events

    func trackAppLaunched() async {
        await track("app_launched", properties: [
            "launch_time": ISO8601DateFormatter().string(from: sessionStartTime)
        ])
    }

    func trackAppTerminated() async {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        await track("app_terminated", properties: [
            "session_duration_seconds": String(format: "%.0f", sessionDuration)
        ])
    }

    func trackRecordingStarted() async {
        await track("recording_started")
    }

    func trackRecordingCompleted(durationSeconds: Double) async {
        let durationBucket = bucketize(durationSeconds, buckets: [1, 5, 10, 30, 60, 120])
        await track("recording_completed", properties: [
            "duration_bucket": durationBucket
        ])
    }

    func trackRecordingCancelled() async {
        await track("recording_cancelled")
    }

    func trackTranscriptionCompleted(latencyMs: Double, success: Bool) async {
        let latencyBucket = bucketize(latencyMs, buckets: [100, 250, 500, 1000, 2500, 5000])
        await track("transcription_completed", properties: [
            "success": String(success),
            "latency_bucket": latencyBucket
        ])
    }

    func trackTextInserted(method: String) async {
        await track("text_inserted", properties: [
            "method": method
        ])
    }

    func trackSettingsChanged(setting: String) async {
        await track("settings_changed", properties: [
            "setting": setting
        ])
    }

    func trackFeatureUsed(_ feature: String) async {
        await track("feature_used", properties: [
            "feature": feature
        ])
    }

    // MARK: - Session Management

    func startNewSession() {
        sessionId = UUID().uuidString
        logToFile("[ANALYTICS] New session started: \(sessionId.prefix(8))")
    }

    func getSessionId() -> String {
        return sessionId
    }

    // MARK: - User Management

    func identify(userId: String, traits: [String: String] = [:]) async {
        guard isEnabled && hasConsent else { return }

        for provider in providers {
            await provider.identify(userId: userId, traits: traits)
        }
    }

    func reset() async {
        startNewSession()

        for provider in providers {
            await provider.reset()
        }
    }

    // MARK: - Data Access

    func getLocalProvider() -> LocalAnalyticsProvider {
        return localProvider
    }

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

    func exportData() -> Data? {
        return localProvider.exportEvents()
    }

    func deleteAllData() async {
        await localProvider.reset()
        clearSuperProperties()
        logToFile("[ANALYTICS] All analytics data deleted")
    }

    // MARK: - Flush

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
