//
//  TracingServiceTests.swift
//  whisperswiftTests
//
//  Tests for TracingService distributed tracing functionality.
//

import XCTest
@testable import whisperswift

final class TracingServiceTests: XCTestCase {

    // MARK: - TraceID Tests

    func test_TraceID_Generation_Produces32HexCharacters() {
        let traceID = TraceID()
        XCTAssertEqual(traceID.value.count, 32)
        XCTAssertTrue(traceID.value.allSatisfy { $0.isHexDigit })
    }

    func test_TraceID_FromValidValue_Succeeds() {
        let validValue = "0123456789abcdef0123456789abcdef"
        let traceID = TraceID(value: validValue)
        XCTAssertNotNil(traceID)
        XCTAssertEqual(traceID?.value, validValue)
    }

    func test_TraceID_FromInvalidLength_ReturnsNil() {
        let shortValue = "0123456789abcdef"
        let traceID = TraceID(value: shortValue)
        XCTAssertNil(traceID)
    }

    func test_TraceID_FromInvalidCharacters_ReturnsNil() {
        let invalidValue = "0123456789abcdef0123456789ghijkl"
        let traceID = TraceID(value: invalidValue)
        XCTAssertNil(traceID)
    }

    func test_TraceID_NormalizesToLowercase() {
        let upperValue = "0123456789ABCDEF0123456789ABCDEF"
        let traceID = TraceID(value: upperValue)
        XCTAssertEqual(traceID?.value, upperValue.lowercased())
    }

    // MARK: - SpanID Tests

    func test_SpanID_Generation_Produces16HexCharacters() {
        let spanID = SpanID()
        XCTAssertEqual(spanID.value.count, 16)
        XCTAssertTrue(spanID.value.allSatisfy { $0.isHexDigit })
    }

    func test_SpanID_FromValidValue_Succeeds() {
        let validValue = "0123456789abcdef"
        let spanID = SpanID(value: validValue)
        XCTAssertNotNil(spanID)
        XCTAssertEqual(spanID?.value, validValue)
    }

    func test_SpanID_FromInvalidLength_ReturnsNil() {
        let shortValue = "01234567"
        let spanID = SpanID(value: shortValue)
        XCTAssertNil(spanID)
    }

    // MARK: - Span Tests

    func test_Span_InitializesWithCorrectValues() {
        let traceID = TraceID()
        let span = Span(traceID: traceID, operationName: "test_operation")

        XCTAssertEqual(span.traceID, traceID)
        XCTAssertEqual(span.operationName, "test_operation")
        XCTAssertNil(span.parentSpanID)
        XCTAssertNil(span.endTime)
        XCTAssertEqual(span.status, .ok)
        XCTAssertTrue(span.attributes.isEmpty)
    }

    func test_Span_Duration_IsNilBeforeEnd() {
        let span = Span(traceID: TraceID(), operationName: "test")
        XCTAssertNil(span.duration)
        XCTAssertNil(span.durationMilliseconds)
    }

    func test_Span_Duration_CalculatesAfterEnd() {
        var span = Span(traceID: TraceID(), operationName: "test")
        span.endTime = span.startTime.addingTimeInterval(1.5)

        XCTAssertNotNil(span.duration)
        XCTAssertEqual(span.duration ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(span.durationMilliseconds ?? 0, 1500, accuracy: 1)
    }

    func test_Span_LogDescription_ContainsOperationName() {
        let span = Span(traceID: TraceID(), operationName: "test_operation")
        let description = span.logDescription()
        XCTAssertTrue(description.contains("test_operation"))
    }

    // MARK: - TracingService Tests

    func test_TracingService_StartTrace_ReturnsTraceID() async {
        let service = TracingService.shared
        await service.clearSpans()

        let traceID = await service.startTrace(operationName: "test_trace")
        XCTAssertEqual(traceID.value.count, 32)

        _ = await service.endTrace()
    }

    func test_TracingService_GetCurrentTraceID_ReturnsActiveTrace() async {
        let service = TracingService.shared
        await service.clearSpans()

        let startedTraceID = await service.startTrace(operationName: "test")
        let currentTraceID = await service.getCurrentTraceID()

        XCTAssertEqual(startedTraceID, currentTraceID)

        _ = await service.endTrace()
    }

    func test_TracingService_EndTrace_ReturnsSpans() async {
        let service = TracingService.shared
        await service.clearSpans()

        _ = await service.startTrace(operationName: "root")
        _ = await service.startSpan(operationName: "child")
        _ = await service.endSpan()

        let spans = await service.endTrace()
        XCTAssertGreaterThanOrEqual(spans.count, 2)
    }

    func test_TracingService_PropagationHeaders_ReturnsW3CFormat() async {
        let service = TracingService.shared
        await service.clearSpans()

        _ = await service.startTrace(operationName: "test")
        let headers = await service.propagationHeaders()

        XCTAssertNotNil(headers["traceparent"])
        let traceparent = headers["traceparent"]!
        XCTAssertTrue(traceparent.hasPrefix("00-"))
        XCTAssertEqual(traceparent.split(separator: "-").count, 4)

        _ = await service.endTrace()
    }

    func test_TracingService_RestoreContext_FromValidHeaders_ReturnsTrue() async {
        let service = TracingService.shared
        await service.clearSpans()

        let headers = ["traceparent": "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01"]
        let result = await service.restoreContext(from: headers)

        XCTAssertTrue(result)
    }

    func test_TracingService_RestoreContext_FromMissingHeader_ReturnsFalse() async {
        let service = TracingService.shared
        await service.clearSpans()

        let headers: [String: String] = [:]
        let result = await service.restoreContext(from: headers)

        XCTAssertFalse(result)
    }

    func test_TracingService_RestoreContext_FromMalformedHeader_ReturnsFalse() async {
        let service = TracingService.shared
        await service.clearSpans()

        let headers = ["traceparent": "invalid-header"]
        let result = await service.restoreContext(from: headers)

        XCTAssertFalse(result)
    }

    func test_TracingService_GetStatistics_ReturnsValidData() async {
        let service = TracingService.shared
        await service.clearSpans()

        _ = await service.startTrace(operationName: "test")
        _ = await service.endSpan()
        _ = await service.endTrace()

        let stats = await service.getStatistics()
        XCTAssertNotNil(stats["totalSpans"])
        XCTAssertNotNil(stats["errorSpans"])
        XCTAssertNotNil(stats["errorRate"])
    }

    func test_TracingService_RecordError_SetsSpanStatusToError() async {
        let service = TracingService.shared
        await service.clearSpans()

        _ = await service.startTrace(operationName: "test")
        await service.recordError(NSError(domain: "test", code: 1))
        let span = await service.endSpan()

        XCTAssertEqual(span?.status, .error)
        _ = await service.endTrace()
    }

    func test_TracingService_AddSpanAttributes_AddsAttributes() async {
        let service = TracingService.shared
        await service.clearSpans()

        _ = await service.startTrace(operationName: "test")
        await service.addSpanAttributes(["key": "value"])
        let span = await service.endSpan()

        XCTAssertEqual(span?.attributes["key"], "value")
        _ = await service.endTrace()
    }

    func test_TracingService_Disabled_DoesNotCreateSpans() async {
        let service = TracingService.shared
        await service.clearSpans()
        await service.setEnabled(false)

        _ = await service.startSpan(operationName: "test")
        let span = await service.endSpan()

        XCTAssertNil(span)

        await service.setEnabled(true)
    }
}
