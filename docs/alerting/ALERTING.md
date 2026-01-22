# WhisperSwift Alerting Configuration

> **Note:** This document describes a **proposed alerting system** that is not yet implemented.
> The `AlertingService` described in the Implementation Guide section is a future enhancement.
> Use this document as a design reference when implementing alerting functionality.

This document describes the alerting strategy for WhisperSwift, including metrics to monitor, recommended thresholds, and integration with macOS notification center.

## Table of Contents

1. [Overview](#overview)
2. [Metrics to Alert On](#metrics-to-alert-on)
3. [Recommended Thresholds](#recommended-thresholds)
4. [Alert Severity Levels](#alert-severity-levels)
5. [macOS Notification Center Integration](#macos-notification-center-integration)
6. [Implementation Guide](#implementation-guide)
7. [Alert Response Procedures](#alert-response-procedures)

## Overview

WhisperSwift uses a local alerting system that monitors key metrics and notifies users through macOS Notification Center when issues occur. This enables proactive problem detection without requiring external monitoring infrastructure.

### Design Principles

- **User-Centric**: Alerts focus on issues that affect user experience
- **Non-Intrusive**: Alerts are batched and throttled to avoid notification fatigue
- **Actionable**: Each alert includes clear guidance on resolution
- **Privacy-Respecting**: No sensitive data in alert messages

## Metrics to Alert On

### Critical Metrics

| Metric | Description | Why Alert |
|--------|-------------|-----------|
| `transcription.failed` | Transcription failures | Direct impact on core functionality |
| `api.groq.errors` | Groq API errors | Service availability issues |
| `recording.failed` | Recording failures | Hardware or permission issues |

### Warning Metrics

| Metric | Description | Why Alert |
|--------|-------------|-----------|
| `transcription.latency_ms` (p95) | 95th percentile latency | Performance degradation |
| `insertion.failed` | Text insertion failures | Accessibility permission issues |
| `api.groq.latency_ms` (p95) | API response time | Network or service issues |

### Informational Metrics

| Metric | Description | Why Alert |
|--------|-------------|-----------|
| `recording.cancelled` (rate) | Cancelled recordings | Potential UX issues |
| `insertion.fallback_clipboard` | Clipboard fallbacks | Missing permissions |

## Recommended Thresholds

### Transcription Metrics

```swift
struct TranscriptionAlertThresholds {
    // Critical: Alert immediately
    static let failureRateThreshold = 0.20  // 20% failure rate
    static let consecutiveFailures = 3       // 3 failures in a row

    // Warning: Alert after pattern emerges
    static let latencyP95Threshold = 5000.0  // 5 seconds
    static let latencyP99Threshold = 10000.0 // 10 seconds

    // Info: Aggregate and report
    static let highLatencyRate = 0.10        // 10% of requests > 3s
}
```

### API Metrics

```swift
struct APIAlertThresholds {
    // Critical
    static let errorRateThreshold = 0.30     // 30% error rate
    static let consecutiveErrors = 5          // 5 consecutive errors

    // Warning
    static let rateLimitThreshold = 3         // 3 rate limit errors in 5 min
    static let timeoutThreshold = 3           // 3 timeouts in 5 min

    // Evaluation windows
    static let shortWindow = 60.0             // 1 minute
    static let longWindow = 300.0             // 5 minutes
}
```

### Recording Metrics

```swift
struct RecordingAlertThresholds {
    // Critical
    static let consecutiveRecordingFailures = 2

    // Warning
    static let silenceDetectionRate = 0.50   // 50% silent recordings
    static let veryShortRecordingRate = 0.30 // 30% < 0.5 seconds
}
```

### System Metrics

```swift
struct SystemAlertThresholds {
    // Warning
    static let highMemoryUsage = 500_000_000 // 500 MB
    static let lowDiskSpace = 100_000_000    // 100 MB

    // Info
    static let longSessionDuration = 86400.0 // 24 hours
}
```

## Alert Severity Levels

### Critical (Red)

**Characteristics:**
- Immediate impact on core functionality
- User cannot complete basic tasks
- Requires immediate attention

**Examples:**
- API key invalid or expired
- No microphone access
- Groq API completely unavailable

**Notification Style:**
- Banner + Sound
- Persistent until acknowledged
- Include "Open Settings" action

### Warning (Yellow)

**Characteristics:**
- Degraded performance or intermittent failures
- User can still complete tasks with retry
- Should be addressed soon

**Examples:**
- High latency (> 5s)
- Intermittent transcription failures
- Accessibility permissions not granted

**Notification Style:**
- Banner only
- Auto-dismiss after 10 seconds
- Include "Learn More" action

### Informational (Blue)

**Characteristics:**
- Performance insights
- Usage patterns
- Non-urgent issues

**Examples:**
- Session statistics
- Tip for better performance
- Feature suggestion

**Notification Style:**
- Notification Center only (no banner)
- Grouped by category
- No sound

## macOS Notification Center Integration

### Setup

WhisperSwift uses `UserNotifications` framework for alerts:

```swift
import UserNotifications

class AlertingService {
    func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                logToFile("[ALERTING] Notification permissions granted")
            }
        }
    }
}
```

### Notification Categories

Define notification categories for user actions:

```swift
func setupNotificationCategories() {
    let openSettingsAction = UNNotificationAction(
        identifier: "OPEN_SETTINGS",
        title: "Open Settings",
        options: .foreground
    )

    let dismissAction = UNNotificationAction(
        identifier: "DISMISS",
        title: "Dismiss",
        options: .destructive
    )

    let criticalCategory = UNNotificationCategory(
        identifier: "CRITICAL_ALERT",
        actions: [openSettingsAction, dismissAction],
        intentIdentifiers: [],
        options: .customDismissAction
    )

    let warningCategory = UNNotificationCategory(
        identifier: "WARNING_ALERT",
        actions: [dismissAction],
        intentIdentifiers: [],
        options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([
        criticalCategory,
        warningCategory
    ])
}
```

### Sending Notifications

```swift
func sendAlert(
    title: String,
    body: String,
    severity: AlertSeverity,
    category: String? = nil
) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = severity == .critical ? .default : nil
    content.categoryIdentifier = category ?? severity.categoryIdentifier

    // Thread identifier for grouping
    content.threadIdentifier = "whisperswift-alerts"

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil // Deliver immediately
    )

    UNUserNotificationCenter.current().add(request)
}
```

### Throttling

Prevent notification fatigue:

```swift
class AlertThrottler {
    private var lastAlertTimes: [String: Date] = [:]
    private let minimumIntervals: [AlertSeverity: TimeInterval] = [
        .critical: 60,      // 1 minute
        .warning: 300,      // 5 minutes
        .info: 3600         // 1 hour
    ]

    func shouldSendAlert(identifier: String, severity: AlertSeverity) -> Bool {
        let now = Date()
        let key = "\(identifier)-\(severity.rawValue)"

        if let lastTime = lastAlertTimes[key] {
            let interval = minimumIntervals[severity] ?? 300
            if now.timeIntervalSince(lastTime) < interval {
                return false
            }
        }

        lastAlertTimes[key] = now
        return true
    }
}
```

## Implementation Guide

### Step 1: Create AlertingService

```swift
// whisperswift/Services/AlertingService.swift

actor AlertingService {
    static let shared = AlertingService()

    private let metricsService = MetricsService.shared
    private let throttler = AlertThrottler()

    private var isEnabled = true
    private var checkInterval: TimeInterval = 30 // Check every 30 seconds

    func startMonitoring() {
        Task {
            while isEnabled {
                await checkMetrics()
                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
    }

    private func checkMetrics() async {
        await checkTranscriptionMetrics()
        await checkAPIMetrics()
        await checkRecordingMetrics()
    }

    private func checkTranscriptionMetrics() async {
        let stats = await metricsService.getHistogramStats("transcription.latency_ms")
        if let stats = stats, stats.p95 > TranscriptionAlertThresholds.latencyP95Threshold {
            await sendWarning(
                identifier: "high_latency",
                title: "High Transcription Latency",
                body: "Transcription is taking longer than usual. Check your network connection."
            )
        }
    }
}
```

### Step 2: Integrate with Metrics

Connect alerting to the metrics collection:

```swift
// In MetricsService, add alert triggers
func recordTranscriptionFailed(error: String, latencyMilliseconds: Double?) {
    increment("transcription.failed", tags: ["error": error])

    // Check for alert condition
    Task {
        await AlertingService.shared.checkImmediateCondition(
            metric: "transcription.failed",
            threshold: TranscriptionAlertThresholds.consecutiveFailures
        )
    }
}
```

### Step 3: Handle User Actions

```swift
// In AppDelegate or dedicated handler
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "OPEN_SETTINGS":
            statusBarController?.openSettings()
        case "DISMISS":
            // Log dismissal for analytics
            Task {
                await AnalyticsService.shared.track("alert_dismissed", properties: [
                    "notification_id": response.notification.request.identifier
                ])
            }
        default:
            break
        }
        completionHandler()
    }
}
```

## Alert Response Procedures

### API Key Invalid

**Alert:** "API Key Invalid - Transcription Unavailable"

**Steps:**
1. Open Settings from alert or menu bar
2. Verify API key is entered correctly
3. Check Groq dashboard for key status
4. Generate new key if needed

### Microphone Access Denied

**Alert:** "Microphone Access Required"

**Steps:**
1. Open System Preferences > Privacy & Security
2. Select Microphone
3. Enable WhisperSwift
4. Restart app if needed

### High Latency

**Alert:** "High Transcription Latency Detected"

**Steps:**
1. Check network connection
2. Verify Groq service status
3. Try shorter recordings
4. Consider using different transcription model

### Accessibility Not Granted

**Alert:** "Enable Accessibility for Auto-Insert"

**Steps:**
1. Open System Preferences > Privacy & Security
2. Select Accessibility
3. Add WhisperSwift
4. Restart app

## Monitoring Dashboard (Future)

For advanced users or debugging, consider adding a monitoring view:

```swift
struct MonitoringView: View {
    @State private var summary: MetricsSummary?
    @State private var alerts: [AlertRecord] = []

    var body: some View {
        VStack {
            // Key metrics
            MetricsGridView(summary: summary)

            // Recent alerts
            AlertsListView(alerts: alerts)

            // Health status
            HealthStatusView()
        }
    }
}
```

## Best Practices

1. **Start Conservative**: Begin with higher thresholds and lower frequency
2. **Learn from Data**: Adjust thresholds based on actual usage patterns
3. **User Control**: Allow users to customize or disable specific alerts
4. **Clear Actions**: Every alert should have a clear resolution path
5. **Test Thoroughly**: Verify alerts work correctly in all scenarios
6. **Log Everything**: Record alert history for debugging and analysis
