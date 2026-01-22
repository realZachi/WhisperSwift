//
//  TracingService.swift
//  whisperswift
//
//  Distributed tracing support for observability.
//  Provides trace ID generation, span creation, and integration with existing logging.
//

import Foundation

/// Represents a unique trace identifier that follows distributed tracing conventions.
/// Compatible with W3C Trace Context format (https://www.w3.org/TR/trace-context/).
struct TraceID: CustomStringConvertible, Equatable, Hashable, Sendable {
    /// 16-byte trace identifier as a hex string (32 characters)
    let value: String

    var description: String { value }

    /// Creates a new random trace ID
    init() {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // Fallback to UUID-based generation if secure random fails
            logToFile("[TRACE] WARNING: SecRandomCopyBytes failed with status \(status), using UUID fallback")
            let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            self.value = String(uuid.prefix(32)).lowercased()
        } else {
            self.value = bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Creates a trace ID from an existing value
    init?(value: String) {
        guard value.count == 32, value.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        self.value = value.lowercased()
    }
}

/// Represents a span identifier within a trace.
struct SpanID: CustomStringConvertible, Equatable, Hashable, Sendable {
    /// 8-byte span identifier as a hex string (16 characters)
    let value: String

    var description: String { value }

    /// Creates a new random span ID
    init() {
        var bytes = [UInt8](repeating: 0, count: 8)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // Fallback to UUID-based generation if secure random fails
            logToFile("[TRACE] WARNING: SecRandomCopyBytes failed with status \(status), using UUID fallback")
            let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            self.value = String(uuid.prefix(16)).lowercased()
        } else {
            self.value = bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Creates a span ID from an existing value
    init?(value: String) {
        guard value.count == 16, value.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        self.value = value.lowercased()
    }
}

/// Represents the status of a span operation.
enum SpanStatus: String, Sendable {
    case ok = "OK"
    case error = "ERROR"
    case cancelled = "CANCELLED"
}

/// Represents a single operation within a trace.
/// Spans capture timing, status, and contextual attributes.
struct Span: Sendable {
    let traceID: TraceID
    let spanID: SpanID
    let parentSpanID: SpanID?
    let operationName: String
    let startTime: Date
    var endTime: Date?
    var status: SpanStatus
    var attributes: [String: String]

    /// Duration of the span in seconds, or nil if not yet ended
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    /// Duration in milliseconds for display purposes
    var durationMilliseconds: Double? {
        guard let duration = duration else { return nil }
        return duration * 1000
    }

    init(
        traceID: TraceID,
        spanID: SpanID = SpanID(),
        parentSpanID: SpanID? = nil,
        operationName: String,
        attributes: [String: String] = [:]
    ) {
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.operationName = operationName
        self.startTime = Date()
        self.endTime = nil
        self.status = .ok
        self.attributes = attributes
    }

    /// Returns the span formatted for logging
    func logDescription() -> String {
        var parts = ["[trace:\(traceID.value.prefix(8))] [span:\(spanID.value.prefix(8))]"]
        if let parentSpanID = parentSpanID {
            parts.append("[parent:\(parentSpanID.value.prefix(8))]")
        }
        parts.append(operationName)
        if let ms = durationMilliseconds {
            parts.append(String(format: "(%.2fms)", ms))
        }
        parts.append("[\(status.rawValue)]")
        if !attributes.isEmpty {
            let attrs = attributes.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            parts.append("{\(attrs)}")
        }
        return parts.joined(separator: " ")
    }
}

/// Thread-safe service for distributed tracing.
/// Manages trace context propagation and span lifecycle.
actor TracingService {
    /// Shared singleton instance
    static let shared = TracingService()

    /// Currently active trace context
    private var currentTraceID: TraceID?
    private var currentSpanID: SpanID?
    private var spanStack: [Span] = []

    /// Whether tracing is enabled
    private var isEnabled: Bool = true

    /// Completed spans for this session (limited buffer)
    private var completedSpans: [Span] = []
    private let maxCompletedSpans = 1000

    private init() {}

    // MARK: - Configuration

    /// Enable or disable tracing
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Returns whether tracing is currently enabled
    func getEnabled() -> Bool {
        return isEnabled
    }

    // MARK: - Trace Management

    /// Starts a new trace with a fresh trace ID.
    /// Returns the new trace ID.
    @discardableResult
    func startTrace(operationName: String, attributes: [String: String] = [:]) -> TraceID {
        let traceID = TraceID()
        currentTraceID = traceID
        currentSpanID = nil
        spanStack.removeAll()

        // Start root span
        _ = startSpan(operationName: operationName, attributes: attributes)

        logSpanEvent("Trace started", traceID: traceID, operationName: operationName)
        return traceID
    }

    /// Ends the current trace and returns all spans.
    func endTrace() -> [Span] {
        guard let traceID = currentTraceID else { return [] }

        // End all remaining spans
        while !spanStack.isEmpty {
            _ = endSpan()
        }

        logSpanEvent("Trace ended", traceID: traceID, operationName: "")

        let spans = completedSpans.filter { $0.traceID == traceID }
        currentTraceID = nil
        currentSpanID = nil
        return spans
    }

    /// Returns the current trace ID if a trace is active.
    func getCurrentTraceID() -> TraceID? {
        return currentTraceID
    }

    // MARK: - Span Management

    /// Starts a new span as a child of the current span.
    /// Returns the new span ID.
    @discardableResult
    func startSpan(operationName: String, attributes: [String: String] = [:]) -> SpanID {
        guard isEnabled else { return SpanID() }

        let traceID = currentTraceID ?? TraceID()
        if currentTraceID == nil {
            currentTraceID = traceID
        }

        let span = Span(
            traceID: traceID,
            parentSpanID: currentSpanID,
            operationName: operationName,
            attributes: attributes
        )

        spanStack.append(span)
        currentSpanID = span.spanID

        logSpanEvent("Span started", traceID: traceID, operationName: operationName)
        return span.spanID
    }

    /// Ends the current span with the given status.
    /// Returns the completed span.
    @discardableResult
    func endSpan(status: SpanStatus = .ok, attributes: [String: String] = [:]) -> Span? {
        guard isEnabled, !spanStack.isEmpty else { return nil }

        var span = spanStack.removeLast()
        span.endTime = Date()
        span.status = status
        for (key, value) in attributes {
            span.attributes[key] = value
        }

        // Update current span ID to parent
        currentSpanID = spanStack.last?.spanID

        // Store completed span
        completedSpans.append(span)
        if completedSpans.count > maxCompletedSpans {
            completedSpans.removeFirst(completedSpans.count - maxCompletedSpans)
        }

        logSpanEvent("Span ended", traceID: span.traceID, operationName: span.operationName, span: span)
        return span
    }

    /// Adds attributes to the current span.
    func addSpanAttributes(_ attributes: [String: String]) {
        guard isEnabled, !spanStack.isEmpty else { return }
        for (key, value) in attributes {
            spanStack[spanStack.count - 1].attributes[key] = value
        }
    }

    /// Records an error on the current span.
    func recordError(_ error: Error, attributes: [String: String] = [:]) {
        guard isEnabled, !spanStack.isEmpty else { return }
        var attrs = attributes
        attrs["error.type"] = String(describing: type(of: error))
        attrs["error.message"] = error.localizedDescription
        addSpanAttributes(attrs)
        spanStack[spanStack.count - 1].status = .error
    }

    // MARK: - Context Propagation

    /// Returns headers for propagating trace context (W3C Trace Context format).
    func propagationHeaders() -> [String: String] {
        guard let traceID = currentTraceID, let spanID = currentSpanID else {
            return [:]
        }

        // W3C Trace Context format: version-traceid-spanid-flags
        let traceparent = "00-\(traceID.value)-\(spanID.value)-01"
        return ["traceparent": traceparent]
    }

    /// Restores trace context from propagation headers.
    /// Returns true if context was successfully restored, false otherwise.
    @discardableResult
    func restoreContext(from headers: [String: String]) -> Bool {
        guard let traceparent = headers["traceparent"] else {
            logToFile("[TRACE] WARNING: No traceparent header found for context restoration")
            return false
        }

        let parts = traceparent.split(separator: "-")
        guard parts.count >= 3 else {
            logToFile("[TRACE] WARNING: Malformed traceparent header: expected 3+ parts, got \(parts.count)")
            return false
        }

        guard let traceID = TraceID(value: String(parts[1])) else {
            logToFile("[TRACE] WARNING: Invalid trace ID in traceparent: \(parts[1])")
            return false
        }

        guard let spanID = SpanID(value: String(parts[2])) else {
            logToFile("[TRACE] WARNING: Invalid span ID in traceparent: \(parts[2])")
            return false
        }

        currentTraceID = traceID
        currentSpanID = spanID
        return true
    }

    // MARK: - Logging Integration

    private func logSpanEvent(_ event: String, traceID: TraceID, operationName: String, span: Span? = nil) {
        var message = "[TRACE] \(event)"
        message += " trace=\(traceID.value.prefix(8))"
        if !operationName.isEmpty {
            message += " op=\(operationName)"
        }
        if let span = span, let ms = span.durationMilliseconds {
            message += String(format: " duration=%.2fms", ms)
            message += " status=\(span.status.rawValue)"
        }
        logToFile(message)
    }

    // MARK: - Statistics

    /// Returns statistics about completed spans.
    func getStatistics() -> [String: Any] {
        let totalSpans = completedSpans.count
        let errorSpans = completedSpans.filter { $0.status == .error }.count
        let avgDuration = completedSpans.compactMap { $0.durationMilliseconds }.reduce(0, +) / Double(max(1, totalSpans))

        return [
            "totalSpans": totalSpans,
            "errorSpans": errorSpans,
            "errorRate": totalSpans > 0 ? Double(errorSpans) / Double(totalSpans) : 0,
            "averageDurationMs": avgDuration
        ]
    }

    /// Clears all completed spans.
    func clearSpans() {
        completedSpans.removeAll()
    }
}

// MARK: - Convenience Extensions

extension TracingService {
    /// Executes a block within a new span, automatically handling span lifecycle.
    func withSpan<T>(
        _ operationName: String,
        attributes: [String: String] = [:],
        body: () async throws -> T
    ) async rethrows -> T {
        _ = startSpan(operationName: operationName, attributes: attributes)
        do {
            let result = try await body()
            _ = endSpan(status: .ok)
            return result
        } catch {
            recordError(error)
            _ = endSpan(status: .error)
            throw error
        }
    }

    /// Executes a synchronous block within a new span.
    func withSpanSync<T>(
        _ operationName: String,
        attributes: [String: String] = [:],
        body: () throws -> T
    ) rethrows -> T {
        // Note: For synchronous operations, we create span inline
        // This is a simplified version that doesn't require actor isolation
        let startTime = Date()
        do {
            let result = try body()
            let duration = Date().timeIntervalSince(startTime)
            logToFile("[TRACE] \(operationName) completed in \(String(format: "%.2fms", duration * 1000))")
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logToFile("[TRACE] \(operationName) failed in \(String(format: "%.2fms", duration * 1000)): \(error.localizedDescription)")
            throw error
        }
    }
}
