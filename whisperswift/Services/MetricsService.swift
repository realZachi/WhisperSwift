//
//  MetricsService.swift
//  whisperswift
//
//  Metrics collection service for observability.
//  Records timing metrics, success/failure counters, audio duration, and API latency.
//

import Foundation

/// Types of metrics supported by the service.
enum MetricType: String, Sendable {
    case counter = "counter"
    case gauge = "gauge"
    case histogram = "histogram"
    case timing = "timing"
}

/// Represents a single metric data point.
struct MetricDataPoint: Sendable {
    let name: String
    let type: MetricType
    let value: Double
    let timestamp: Date
    let tags: [String: String]

    init(name: String, type: MetricType, value: Double, tags: [String: String] = [:]) {
        self.name = name
        self.type = type
        self.value = value
        self.timestamp = Date()
        self.tags = tags
    }
}

/// Histogram bucket for timing distributions.
struct HistogramBucket: Sendable {
    let upperBound: Double
    var count: Int
}

/// Thread-safe service for collecting and reporting metrics.
/// Provides counters, gauges, histograms, and timing metrics.
actor MetricsService {
    /// Shared singleton instance
    static let shared = MetricsService()

    /// Whether metrics collection is enabled
    private var isEnabled: Bool = true

    /// Counter values
    private var counters: [String: Int] = [:]

    /// Gauge values
    private var gauges: [String: Double] = [:]

    /// Histogram values (for timing distributions)
    private var histograms: [String: [Double]] = [:]

    /// Recent metric data points (rolling window)
    private var dataPoints: [MetricDataPoint] = []
    private let maxDataPoints = 10000

    /// Session start time for uptime calculation
    private let sessionStartTime = Date()

    /// Default histogram buckets for timing metrics (in milliseconds)
    private let defaultTimingBuckets: [Double] = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]

    private init() {
        // Initialize default metrics
        initializeDefaultMetrics()
    }

    private func initializeDefaultMetrics() {
        // Recording metrics
        counters["recording.started"] = 0
        counters["recording.completed"] = 0
        counters["recording.cancelled"] = 0
        counters["recording.failed"] = 0

        // Transcription metrics
        counters["transcription.requested"] = 0
        counters["transcription.succeeded"] = 0
        counters["transcription.failed"] = 0

        // Text insertion metrics
        counters["insertion.attempted"] = 0
        counters["insertion.succeeded"] = 0
        counters["insertion.fallback_clipboard"] = 0
        counters["insertion.failed"] = 0

        // API metrics
        counters["api.groq.requests"] = 0
        counters["api.groq.success"] = 0
        counters["api.groq.errors"] = 0

        // Initialize histograms
        histograms["recording.duration_ms"] = []
        histograms["transcription.latency_ms"] = []
        histograms["api.groq.latency_ms"] = []
        histograms["audio.duration_seconds"] = []
    }

    // MARK: - Configuration

    /// Enable or disable metrics collection
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Returns whether metrics is currently enabled
    func getEnabled() -> Bool {
        return isEnabled
    }

    // MARK: - Counter Operations

    /// Increments a counter by the specified amount (default 1).
    func increment(_ name: String, by amount: Int = 1, tags: [String: String] = [:]) {
        guard isEnabled else { return }

        let currentValue = counters[name] ?? 0
        counters[name] = currentValue + amount

        let dataPoint = MetricDataPoint(
            name: name,
            type: .counter,
            value: Double(counters[name]!),
            tags: tags
        )
        recordDataPoint(dataPoint)

        logMetric("Counter", name: name, value: Double(counters[name]!), tags: tags)
    }

    /// Gets the current value of a counter.
    func getCounter(_ name: String) -> Int {
        return counters[name] ?? 0
    }

    // MARK: - Gauge Operations

    /// Sets a gauge to a specific value.
    func setGauge(_ name: String, value: Double, tags: [String: String] = [:]) {
        guard isEnabled else { return }

        gauges[name] = value

        let dataPoint = MetricDataPoint(
            name: name,
            type: .gauge,
            value: value,
            tags: tags
        )
        recordDataPoint(dataPoint)

        logMetric("Gauge", name: name, value: value, tags: tags)
    }

    /// Gets the current value of a gauge.
    func getGauge(_ name: String) -> Double? {
        return gauges[name]
    }

    // MARK: - Histogram/Timing Operations

    /// Records a timing value in milliseconds.
    func recordTiming(_ name: String, milliseconds: Double, tags: [String: String] = [:]) {
        guard isEnabled else { return }

        var values = histograms[name] ?? []
        values.append(milliseconds)

        // Keep last 1000 values per histogram
        if values.count > 1000 {
            values.removeFirst(values.count - 1000)
        }
        histograms[name] = values

        let dataPoint = MetricDataPoint(
            name: name,
            type: .timing,
            value: milliseconds,
            tags: tags
        )
        recordDataPoint(dataPoint)

        logMetric("Timing", name: name, value: milliseconds, tags: tags, unit: "ms")
    }

    /// Records a duration value in seconds (converted to histogram).
    func recordDuration(_ name: String, seconds: Double, tags: [String: String] = [:]) {
        guard isEnabled else { return }

        var values = histograms[name] ?? []
        values.append(seconds)

        if values.count > 1000 {
            values.removeFirst(values.count - 1000)
        }
        histograms[name] = values

        let dataPoint = MetricDataPoint(
            name: name,
            type: .histogram,
            value: seconds,
            tags: tags
        )
        recordDataPoint(dataPoint)

        logMetric("Duration", name: name, value: seconds, tags: tags, unit: "s")
    }

    /// Gets histogram statistics for a metric.
    func getHistogramStats(_ name: String) -> HistogramStats? {
        guard let values = histograms[name], !values.isEmpty else { return nil }

        let sorted = values.sorted()
        let count = sorted.count
        let sum = sorted.reduce(0, +)
        let mean = sum / Double(count)

        let p50Index = Int(Double(count) * 0.50)
        let p90Index = Int(Double(count) * 0.90)
        let p95Index = Int(Double(count) * 0.95)
        let p99Index = Int(Double(count) * 0.99)

        return HistogramStats(
            count: count,
            sum: sum,
            mean: mean,
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            p50: sorted[min(p50Index, count - 1)],
            p90: sorted[min(p90Index, count - 1)],
            p95: sorted[min(p95Index, count - 1)],
            p99: sorted[min(p99Index, count - 1)]
        )
    }

    // MARK: - Convenience Methods for WhisperSwift Metrics

    /// Records the start of a recording session.
    func recordRecordingStarted() {
        increment("recording.started")
    }

    /// Records a completed recording with duration.
    func recordRecordingCompleted(durationSeconds: Double) {
        increment("recording.completed")
        recordDuration("audio.duration_seconds", seconds: durationSeconds)
        recordTiming("recording.duration_ms", milliseconds: durationSeconds * 1000)
    }

    /// Records a cancelled recording.
    func recordRecordingCancelled() {
        increment("recording.cancelled")
    }

    /// Records a failed recording with error.
    func recordRecordingFailed(error: String) {
        increment("recording.failed", tags: ["error": error])
    }

    /// Records the start of a transcription request.
    func recordTranscriptionRequested(audioSeconds: Double) {
        increment("transcription.requested")
        increment("api.groq.requests")
        setGauge("transcription.audio_duration", value: audioSeconds)
    }

    /// Records a successful transcription with latency.
    func recordTranscriptionSucceeded(latencyMilliseconds: Double, characterCount: Int) {
        increment("transcription.succeeded")
        increment("api.groq.success")
        recordTiming("transcription.latency_ms", milliseconds: latencyMilliseconds)
        recordTiming("api.groq.latency_ms", milliseconds: latencyMilliseconds)
        setGauge("transcription.last_character_count", value: Double(characterCount))
    }

    /// Records a failed transcription.
    func recordTranscriptionFailed(error: String, latencyMilliseconds: Double? = nil) {
        increment("transcription.failed", tags: ["error": error])
        increment("api.groq.errors", tags: ["error": error])
        if let latency = latencyMilliseconds {
            recordTiming("api.groq.latency_ms", milliseconds: latency, tags: ["status": "error"])
        }
    }

    /// Records a text insertion attempt and result.
    func recordTextInsertion(outcome: String) {
        increment("insertion.attempted")
        switch outcome {
        case "inserted":
            increment("insertion.succeeded")
        case "clipboard":
            increment("insertion.fallback_clipboard")
        case "failed":
            increment("insertion.failed")
        default:
            break
        }
    }

    // MARK: - Data Point Management

    private func recordDataPoint(_ dataPoint: MetricDataPoint) {
        dataPoints.append(dataPoint)
        if dataPoints.count > maxDataPoints {
            dataPoints.removeFirst(dataPoints.count - maxDataPoints)
        }
    }

    // MARK: - Reporting

    /// Returns all current metrics as a dictionary.
    func getAllMetrics() -> [String: Any] {
        var result: [String: Any] = [:]

        // Counters
        var counterDict: [String: Int] = [:]
        for (key, value) in counters {
            counterDict[key] = value
        }
        result["counters"] = counterDict

        // Gauges
        var gaugeDict: [String: Double] = [:]
        for (key, value) in gauges {
            gaugeDict[key] = value
        }
        result["gauges"] = gaugeDict

        // Histogram stats
        var histogramDict: [String: Any] = [:]
        for (key, _) in histograms {
            if let stats = getHistogramStats(key) {
                histogramDict[key] = [
                    "count": stats.count,
                    "mean": stats.mean,
                    "min": stats.min,
                    "max": stats.max,
                    "p50": stats.p50,
                    "p90": stats.p90,
                    "p95": stats.p95,
                    "p99": stats.p99
                ]
            }
        }
        result["histograms"] = histogramDict

        // Session info
        result["session"] = [
            "startTime": sessionStartTime,
            "uptimeSeconds": Date().timeIntervalSince(sessionStartTime)
        ]

        return result
    }

    /// Returns a summary of key metrics for display.
    func getSummary() -> MetricsSummary {
        let transcriptionSuccessRate: Double
        let totalTranscriptions = getCounter("transcription.requested")
        if totalTranscriptions > 0 {
            transcriptionSuccessRate = Double(getCounter("transcription.succeeded")) / Double(totalTranscriptions)
        } else {
            transcriptionSuccessRate = 1.0
        }

        let avgTranscriptionLatency = getHistogramStats("transcription.latency_ms")?.mean ?? 0
        let avgAudioDuration = getHistogramStats("audio.duration_seconds")?.mean ?? 0

        return MetricsSummary(
            totalRecordings: getCounter("recording.completed"),
            totalTranscriptions: getCounter("transcription.succeeded"),
            transcriptionSuccessRate: transcriptionSuccessRate,
            averageTranscriptionLatencyMs: avgTranscriptionLatency,
            averageAudioDurationSeconds: avgAudioDuration,
            uptimeSeconds: Date().timeIntervalSince(sessionStartTime)
        )
    }

    /// Resets all metrics to initial values.
    func reset() {
        counters.removeAll()
        gauges.removeAll()
        histograms.removeAll()
        dataPoints.removeAll()
        initializeDefaultMetrics()
        logToFile("[METRICS] All metrics reset")
    }

    // MARK: - Logging

    private func logMetric(_ type: String, name: String, value: Double, tags: [String: String], unit: String? = nil) {
        var message = "[METRICS] \(type) \(name)=\(String(format: "%.2f", value))"
        if let unit = unit {
            message += unit
        }
        if !tags.isEmpty {
            let tagStr = tags.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
            message += " {\(tagStr)}"
        }
        logToFile(message)
    }
}

// MARK: - Supporting Types

/// Statistics calculated from histogram values.
struct HistogramStats: Sendable {
    let count: Int
    let sum: Double
    let mean: Double
    let min: Double
    let max: Double
    let p50: Double
    let p90: Double
    let p95: Double
    let p99: Double
}

/// Summary of key metrics for display.
struct MetricsSummary: Sendable {
    let totalRecordings: Int
    let totalTranscriptions: Int
    let transcriptionSuccessRate: Double
    let averageTranscriptionLatencyMs: Double
    let averageAudioDurationSeconds: Double
    let uptimeSeconds: TimeInterval

    var formattedSuccessRate: String {
        String(format: "%.1f%%", transcriptionSuccessRate * 100)
    }

    var formattedUptime: String {
        let hours = Int(uptimeSeconds) / 3600
        let minutes = (Int(uptimeSeconds) % 3600) / 60
        let seconds = Int(uptimeSeconds) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Timing Helper

/// Helper class for measuring operation timing.
final class MetricTimer: @unchecked Sendable {
    private let startTime: Date
    private let metricName: String
    private let tags: [String: String]
    private var ended = false

    init(metricName: String, tags: [String: String] = [:]) {
        self.startTime = Date()
        self.metricName = metricName
        self.tags = tags
    }

    /// Ends the timer and records the duration.
    func end() async {
        guard !ended else { return }
        ended = true
        let elapsed = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
        await MetricsService.shared.recordTiming(metricName, milliseconds: elapsed, tags: tags)
    }

    /// Returns the elapsed time in milliseconds without recording.
    func elapsedMilliseconds() -> Double {
        return Date().timeIntervalSince(startTime) * 1000
    }
}
