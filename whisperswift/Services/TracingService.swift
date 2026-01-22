//
//  TracingService.swift
//  whisperswift
//

import Foundation

struct TraceID: CustomStringConvertible, Equatable, Hashable, Sendable {
    let value: String

    var description: String { value }

    init() {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            self.value = bytes.map { String(format: "%02x", $0) }.joined()
        } else {
            let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            self.value = String(uuid.prefix(32)).lowercased()
        }
    }

    init?(value: String) {
        guard value.count == 32, value.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        self.value = value.lowercased()
    }
}

struct SpanID: CustomStringConvertible, Equatable, Hashable, Sendable {
    let value: String

    var description: String { value }

    init() {
        var bytes = [UInt8](repeating: 0, count: 8)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            self.value = bytes.map { String(format: "%02x", $0) }.joined()
        } else {
            let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            self.value = String(uuid.prefix(16)).lowercased()
        }
    }

    init?(value: String) {
        guard value.count == 16, value.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        self.value = value.lowercased()
    }
}

enum SpanStatus: String, Sendable {
    case ok = "OK"
    case error = "ERROR"
    case cancelled = "CANCELLED"
}

struct Span: Sendable {
    let traceID: TraceID
    let spanID: SpanID
    let parentSpanID: SpanID?
    let operationName: String
    let startTime: Date
    var endTime: Date?
    var status: SpanStatus
    var attributes: [String: String]

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

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

actor TracingService {
    static let shared = TracingService()

    private var currentTraceID: TraceID?
    private var currentSpanID: SpanID?
    private var spanStack: [Span] = []
    private var isEnabled: Bool = true
    private var completedSpans: [Span] = []
    private let maxCompletedSpans = 1000

    private init() {}

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func getEnabled() -> Bool {
        return isEnabled
    }

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

    func getCurrentTraceID() -> TraceID? {
        return currentTraceID
    }

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

    func addSpanAttributes(_ attributes: [String: String]) {
        guard isEnabled, !spanStack.isEmpty else { return }
        for (key, value) in attributes {
            spanStack[spanStack.count - 1].attributes[key] = value
        }
    }

    func recordError(_ error: Error, attributes: [String: String] = [:]) {
        guard isEnabled, !spanStack.isEmpty else { return }
        var attrs = attributes
        attrs["error.type"] = String(describing: type(of: error))
        attrs["error.message"] = error.localizedDescription
        addSpanAttributes(attrs)
        spanStack[spanStack.count - 1].status = .error
    }

    func propagationHeaders() -> [String: String] {
        guard let traceID = currentTraceID, let spanID = currentSpanID else {
            return [:]
        }

        // W3C Trace Context format: version-traceid-spanid-flags
        let traceparent = "00-\(traceID.value)-\(spanID.value)-01"
        return ["traceparent": traceparent]
    }

    @discardableResult
    func restoreContext(from headers: [String: String]) -> Bool {
        guard let traceparent = headers["traceparent"] else { return false }

        let parts = traceparent.split(separator: "-")
        guard parts.count >= 3,
              let traceID = TraceID(value: String(parts[1])),
              let spanID = SpanID(value: String(parts[2])) else {
            return false
        }

        currentTraceID = traceID
        currentSpanID = spanID
        return true
    }

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

    func clearSpans() {
        completedSpans.removeAll()
    }
}

extension TracingService {
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

    func withSpanSync<T>(
        _ operationName: String,
        attributes: [String: String] = [:],
        body: () throws -> T
    ) rethrows -> T {
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
