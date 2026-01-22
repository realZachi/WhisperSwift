//
//  ErrorTrackingService.swift
//  whisperswift
//
//  Error tracking service for observability.
//  Provides a Sentry-compatible interface with local implementation.
//
//  ## Integration with Sentry
//
//  To integrate Sentry for production error tracking:
//
//  1. Add Sentry SDK to your project:
//     - Add to Package.swift or via CocoaPods/Carthage:
//       .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0")
//
//  2. Initialize Sentry in AppDelegate:
//     ```swift
//     import Sentry
//
//     SentrySDK.start { options in
//         options.dsn = "YOUR_SENTRY_DSN"
//         options.debug = false
//         options.tracesSampleRate = 1.0
//         options.attachStacktrace = true
//         options.environment = "production"
//     }
//     ```
//
//  3. Implement SentryErrorTracker:
//     ```swift
//     class SentryErrorTracker: ErrorTrackerProtocol {
//         func captureError(_ error: Error, context: ErrorContext) {
//             let sentryEvent = Event(level: context.severity.sentryLevel)
//             sentryEvent.message = SentryMessage(formatted: error.localizedDescription)
//             sentryEvent.extra = context.metadata
//             sentryEvent.tags = context.tags
//             SentrySDK.capture(event: sentryEvent)
//         }
//
//         func captureMessage(_ message: String, severity: ErrorSeverity, context: ErrorContext) {
//             SentrySDK.capture(message: message)
//         }
//
//         func setUser(id: String?, email: String?, username: String?) {
//             let user = User()
//             user.userId = id
//             user.email = email
//             user.username = username
//             SentrySDK.setUser(user)
//         }
//
//         func addBreadcrumb(category: String, message: String, level: ErrorSeverity, data: [String: Any]?) {
//             let crumb = Breadcrumb()
//             crumb.category = category
//             crumb.message = message
//             crumb.level = level.sentryLevel
//             crumb.data = data
//             SentrySDK.addBreadcrumb(crumb)
//         }
//     }
//     ```
//
//  4. Replace the local tracker:
//     ```swift
//     await ErrorTrackingService.shared.setTracker(SentryErrorTracker())
//     ```
//

import Foundation

/// Severity levels for errors and messages.
enum ErrorSeverity: String, Sendable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case fatal = "fatal"

    /// Returns the emoji representation for logging
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .fatal: return "💥"
        }
    }
}

/// Context information attached to errors.
struct ErrorContext: Sendable {
    let severity: ErrorSeverity
    let tags: [String: String]
    let metadata: [String: String]
    let breadcrumbs: [ErrorBreadcrumb]

    init(
        severity: ErrorSeverity = .error,
        tags: [String: String] = [:],
        metadata: [String: String] = [:],
        breadcrumbs: [ErrorBreadcrumb] = []
    ) {
        self.severity = severity
        self.tags = tags
        self.metadata = metadata
        self.breadcrumbs = breadcrumbs
    }
}

/// Breadcrumb for tracking user/system actions leading to an error.
struct ErrorBreadcrumb: Sendable {
    let timestamp: Date
    let category: String
    let message: String
    let level: ErrorSeverity
    let data: [String: String]

    init(
        category: String,
        message: String,
        level: ErrorSeverity = .info,
        data: [String: String] = [:]
    ) {
        self.timestamp = Date()
        self.category = category
        self.message = message
        self.level = level
        self.data = data
    }
}

/// Captured error record for local storage.
struct CapturedError: Sendable {
    let id: String
    let timestamp: Date
    let error: String
    let errorType: String
    let context: ErrorContext
    let stackTrace: String?

    init(error: Error, context: ErrorContext, stackTrace: String? = nil) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.error = error.localizedDescription
        self.errorType = String(describing: type(of: error))
        self.context = context
        self.stackTrace = stackTrace
    }

    init(message: String, context: ErrorContext, stackTrace: String? = nil) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.error = message
        self.errorType = "Message"
        self.context = context
        self.stackTrace = stackTrace
    }
}

/// Protocol for error tracking implementations.
/// Implement this protocol to integrate with external error tracking services.
protocol ErrorTrackerProtocol: Sendable {
    /// Captures an error with context.
    func captureError(_ error: Error, context: ErrorContext) async

    /// Captures a message with severity and context.
    func captureMessage(_ message: String, severity: ErrorSeverity, context: ErrorContext) async

    /// Sets the current user for error attribution.
    func setUser(id: String?, email: String?, username: String?) async

    /// Adds a breadcrumb for tracking user actions.
    func addBreadcrumb(category: String, message: String, level: ErrorSeverity, data: [String: String]?) async

    /// Clears the current user.
    func clearUser() async

    /// Flushes any pending error reports.
    func flush() async
}

/// Local error tracker that logs errors with full context.
/// Use this for development or as a fallback when external services are unavailable.
final class LocalErrorTracker: ErrorTrackerProtocol, @unchecked Sendable {
    private var capturedErrors: [CapturedError] = []
    private var breadcrumbs: [ErrorBreadcrumb] = []
    private var userId: String?
    private var userEmail: String?
    private var username: String?
    private let maxErrors = 500
    private let maxBreadcrumbs = 100
    private let lock = NSLock()

    func captureError(_ error: Error, context: ErrorContext) async {
        let captured = CapturedError(
            error: error,
            context: context,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n")
        )

        lock.lock()
        capturedErrors.append(captured)
        if capturedErrors.count > maxErrors {
            capturedErrors.removeFirst(capturedErrors.count - maxErrors)
        }
        lock.unlock()

        logError(captured)
    }

    func captureMessage(_ message: String, severity: ErrorSeverity, context: ErrorContext) async {
        let captured = CapturedError(
            message: message,
            context: ErrorContext(
                severity: severity,
                tags: context.tags,
                metadata: context.metadata,
                breadcrumbs: context.breadcrumbs
            )
        )

        lock.lock()
        capturedErrors.append(captured)
        if capturedErrors.count > maxErrors {
            capturedErrors.removeFirst(capturedErrors.count - maxErrors)
        }
        lock.unlock()

        logError(captured)
    }

    func setUser(id: String?, email: String?, username: String?) async {
        lock.lock()
        self.userId = id
        self.userEmail = email
        self.username = username
        lock.unlock()
        logToFile("[ERROR_TRACKING] User set: id=\(id ?? "nil"), username=\(username ?? "nil")")
    }

    func clearUser() async {
        lock.lock()
        self.userId = nil
        self.userEmail = nil
        self.username = nil
        lock.unlock()
        logToFile("[ERROR_TRACKING] User cleared")
    }

    func addBreadcrumb(category: String, message: String, level: ErrorSeverity, data: [String: String]?) async {
        let breadcrumb = ErrorBreadcrumb(
            category: category,
            message: message,
            level: level,
            data: data ?? [:]
        )

        lock.lock()
        breadcrumbs.append(breadcrumb)
        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs.removeFirst(breadcrumbs.count - maxBreadcrumbs)
        }
        lock.unlock()

        logToFile("[BREADCRUMB] [\(category)] \(message)")
    }

    func flush() async {
        // Local tracker doesn't need to flush
        logToFile("[ERROR_TRACKING] Flush requested (no-op for local tracker)")
    }

    private func logError(_ captured: CapturedError) {
        var message = "[ERROR_TRACKING] \(captured.context.severity.emoji) [\(captured.context.severity.rawValue.uppercased())]"
        message += " \(captured.errorType): \(captured.error)"

        if !captured.context.tags.isEmpty {
            let tags = captured.context.tags.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " tags={\(tags)}"
        }

        if !captured.context.metadata.isEmpty {
            let meta = captured.context.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            message += " meta={\(meta)}"
        }

        logToFile(message)
    }

    /// Returns all captured errors for inspection.
    func getCapturedErrors() -> [CapturedError] {
        lock.lock()
        defer { lock.unlock() }
        return capturedErrors
    }

    /// Returns recent breadcrumbs.
    func getBreadcrumbs() -> [ErrorBreadcrumb] {
        lock.lock()
        defer { lock.unlock() }
        return breadcrumbs
    }

    /// Clears all captured errors and breadcrumbs.
    func clear() {
        lock.lock()
        capturedErrors.removeAll()
        breadcrumbs.removeAll()
        lock.unlock()
        logToFile("[ERROR_TRACKING] Cleared all captured errors and breadcrumbs")
    }

    /// Returns error statistics.
    func getStatistics() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        let errorsBySeverity = Dictionary(grouping: capturedErrors) { $0.context.severity }
            .mapValues { $0.count }

        let errorsByType = Dictionary(grouping: capturedErrors) { $0.errorType }
            .mapValues { $0.count }

        return [
            "totalErrors": capturedErrors.count,
            "totalBreadcrumbs": breadcrumbs.count,
            "errorsBySeverity": errorsBySeverity.mapKeys { $0.rawValue },
            "errorsByType": errorsByType
        ]
    }
}

/// Thread-safe error tracking service.
/// Provides a unified interface for error tracking with pluggable backends.
actor ErrorTrackingService {
    /// Shared singleton instance
    static let shared = ErrorTrackingService()

    /// The active error tracker implementation
    private var tracker: any ErrorTrackerProtocol

    /// Whether error tracking is enabled
    private var isEnabled: Bool = true

    /// Global tags applied to all errors
    private var globalTags: [String: String] = [:]

    /// Global metadata applied to all errors
    private var globalMetadata: [String: String] = [:]

    private init() {
        self.tracker = LocalErrorTracker()
    }

    // MARK: - Configuration

    /// Sets the error tracker implementation.
    func setTracker(_ tracker: any ErrorTrackerProtocol) {
        self.tracker = tracker
    }

    /// Returns the current tracker (useful for accessing local tracker features).
    func getTracker() -> any ErrorTrackerProtocol {
        return tracker
    }

    /// Enable or disable error tracking.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Returns whether error tracking is enabled.
    func getEnabled() -> Bool {
        return isEnabled
    }

    /// Sets global tags applied to all errors.
    func setGlobalTags(_ tags: [String: String]) {
        globalTags = tags
    }

    /// Adds a global tag.
    func addGlobalTag(key: String, value: String) {
        globalTags[key] = value
    }

    /// Sets global metadata applied to all errors.
    func setGlobalMetadata(_ metadata: [String: String]) {
        globalMetadata = metadata
    }

    // MARK: - Error Capture

    /// Captures an error with optional additional context.
    func captureError(
        _ error: Error,
        severity: ErrorSeverity = .error,
        tags: [String: String] = [:],
        metadata: [String: String] = [:]
    ) async {
        guard isEnabled else { return }

        var mergedTags = globalTags
        for (key, value) in tags {
            mergedTags[key] = value
        }

        var mergedMetadata = globalMetadata
        for (key, value) in metadata {
            mergedMetadata[key] = value
        }

        let context = ErrorContext(
            severity: severity,
            tags: mergedTags,
            metadata: mergedMetadata
        )

        await tracker.captureError(error, context: context)
    }

    /// Captures a message with severity and optional context.
    func captureMessage(
        _ message: String,
        severity: ErrorSeverity = .info,
        tags: [String: String] = [:],
        metadata: [String: String] = [:]
    ) async {
        guard isEnabled else { return }

        var mergedTags = globalTags
        for (key, value) in tags {
            mergedTags[key] = value
        }

        var mergedMetadata = globalMetadata
        for (key, value) in metadata {
            mergedMetadata[key] = value
        }

        let context = ErrorContext(
            severity: severity,
            tags: mergedTags,
            metadata: mergedMetadata
        )

        await tracker.captureMessage(message, severity: severity, context: context)
    }

    // MARK: - User Context

    /// Sets the current user for error attribution.
    func setUser(id: String? = nil, email: String? = nil, username: String? = nil) async {
        await tracker.setUser(id: id, email: email, username: username)
    }

    /// Clears the current user.
    func clearUser() async {
        await tracker.clearUser()
    }

    // MARK: - Breadcrumbs

    /// Adds a breadcrumb for tracking user/system actions.
    func addBreadcrumb(
        category: String,
        message: String,
        level: ErrorSeverity = .info,
        data: [String: String]? = nil
    ) async {
        guard isEnabled else { return }
        await tracker.addBreadcrumb(category: category, message: message, level: level, data: data)
    }

    // MARK: - Convenience Methods for WhisperSwift

    /// Captures a recording error.
    func captureRecordingError(_ error: Error) async {
        await captureError(
            error,
            severity: .error,
            tags: ["component": "audio_recorder"],
            metadata: ["operation": "recording"]
        )
    }

    /// Captures a transcription error.
    func captureTranscriptionError(_ error: Error, audioSeconds: Double? = nil) async {
        var metadata: [String: String] = ["operation": "transcription"]
        if let seconds = audioSeconds {
            metadata["audio_duration_seconds"] = String(format: "%.2f", seconds)
        }

        await captureError(
            error,
            severity: .error,
            tags: ["component": "groq_transcription"],
            metadata: metadata
        )
    }

    /// Captures an API error.
    func captureAPIError(_ error: Error, endpoint: String, statusCode: Int? = nil) async {
        var metadata: [String: String] = [
            "operation": "api_request",
            "endpoint": endpoint
        ]
        if let code = statusCode {
            metadata["status_code"] = String(code)
        }

        await captureError(
            error,
            severity: .error,
            tags: ["component": "api", "service": "groq"],
            metadata: metadata
        )
    }

    /// Captures a text insertion error.
    func captureInsertionError(_ error: Error, method: String) async {
        await captureError(
            error,
            severity: .warning,
            tags: ["component": "text_insertion"],
            metadata: ["method": method]
        )
    }

    // MARK: - Flush

    /// Flushes any pending error reports.
    func flush() async {
        await tracker.flush()
    }
}

// MARK: - Dictionary Extension

extension Dictionary {
    /// Maps dictionary keys using a transform function.
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
