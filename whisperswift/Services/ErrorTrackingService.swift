//
//  ErrorTrackingService.swift
//  whisperswift
//

import Foundation

enum ErrorSeverity: String, Sendable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case fatal = "fatal"

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

protocol ErrorTrackerProtocol: Sendable {
    func captureError(_ error: Error, context: ErrorContext) async
    func captureMessage(_ message: String, severity: ErrorSeverity, context: ErrorContext) async
    func setUser(id: String?, email: String?, username: String?) async
    func addBreadcrumb(category: String, message: String, level: ErrorSeverity, data: [String: String]?) async
    func clearUser() async
    func flush() async
}

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

    func flush() async {}

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

    func getCapturedErrors() -> [CapturedError] {
        lock.lock()
        defer { lock.unlock() }
        return capturedErrors
    }

    func getBreadcrumbs() -> [ErrorBreadcrumb] {
        lock.lock()
        defer { lock.unlock() }
        return breadcrumbs
    }

    func clear() {
        lock.lock()
        capturedErrors.removeAll()
        breadcrumbs.removeAll()
        lock.unlock()
    }

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

actor ErrorTrackingService {
    static let shared = ErrorTrackingService()

    private var tracker: any ErrorTrackerProtocol
    private var isEnabled: Bool = true
    private var globalTags: [String: String] = [:]
    private var globalMetadata: [String: String] = [:]

    private init() {
        self.tracker = LocalErrorTracker()
    }

    func setTracker(_ tracker: any ErrorTrackerProtocol) {
        self.tracker = tracker
    }

    func getTracker() -> any ErrorTrackerProtocol {
        return tracker
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func getEnabled() -> Bool {
        return isEnabled
    }

    func setGlobalTags(_ tags: [String: String]) {
        globalTags = tags
    }

    func addGlobalTag(key: String, value: String) {
        globalTags[key] = value
    }

    func setGlobalMetadata(_ metadata: [String: String]) {
        globalMetadata = metadata
    }

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

    func setUser(id: String? = nil, email: String? = nil, username: String? = nil) async {
        await tracker.setUser(id: id, email: email, username: username)
    }

    func clearUser() async {
        await tracker.clearUser()
    }

    func addBreadcrumb(
        category: String,
        message: String,
        level: ErrorSeverity = .info,
        data: [String: String]? = nil
    ) async {
        guard isEnabled else { return }
        await tracker.addBreadcrumb(category: category, message: message, level: level, data: data)
    }

    func captureRecordingError(_ error: Error) async {
        await captureError(
            error,
            severity: .error,
            tags: ["component": "audio_recorder"],
            metadata: ["operation": "recording"]
        )
    }

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

    func captureInsertionError(_ error: Error, method: String) async {
        await captureError(
            error,
            severity: .warning,
            tags: ["component": "text_insertion"],
            metadata: ["method": method]
        )
    }

    func flush() async {
        await tracker.flush()
    }
}

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
