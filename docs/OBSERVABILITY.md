# Observability Services

## TracingService

Distributed tracing with W3C Trace Context format:
- Span hierarchies
- Error recording
- Context propagation

## MetricsService

Metrics collection with bounded storage (max 10,000 data points):
- Counters
- Gauges
- Histograms
- Timing metrics

## ErrorTrackingService

Error aggregation with:
- Severity levels: debug → info → warning → error → fatal
- Breadcrumbs for debugging context

## AnalyticsService

Event-based analytics with:
- Session management
- Bounded event storage (max 10,000 events)
