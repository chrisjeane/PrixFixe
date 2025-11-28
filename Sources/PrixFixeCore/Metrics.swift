/// Production Monitoring and Metrics Infrastructure
///
/// This module provides structured metrics collection for production deployments.
/// Metrics are emitted as structured log output that can be parsed by monitoring
/// systems (Prometheus, DataDog, CloudWatch, etc.).

import Foundation

/// Metrics collector for SMTP server operations.
///
/// `MetricsCollector` tracks operational metrics for production monitoring including
/// connection counts, latency distributions, error rates, and throughput.
///
/// ## Usage
///
/// ```swift
/// let metrics = MetricsCollector()
///
/// // Record connection metrics
/// metrics.recordConnectionAccepted(latency: 0.002)
///
/// // Record message processing
/// metrics.recordMessageProcessed(size: 1024)
///
/// // Emit periodic metrics
/// metrics.emitMetrics()
/// ```
///
/// ## Metrics Output
///
/// Metrics are emitted as JSON-formatted log lines to stdout for consumption
/// by external monitoring systems. Each metric includes a timestamp and type.
public actor MetricsCollector {
    /// Current count of active connections
    private var activeConnections: Int = 0

    /// Total connections accepted
    private var totalConnectionsAccepted: Int = 0

    /// Connection accept latency samples (in seconds)
    private var acceptLatencySamples: [TimeInterval] = []

    /// Message processing latency samples (in seconds)
    private var messageLatencySamples: [TimeInterval] = []

    /// Total messages processed
    private var messagesProcessed: Int = 0

    /// Total bytes transferred
    private var bytesTransferred: Int = 0

    /// Error counts by type
    private var errorCounts: [String: Int] = [:]

    /// TLS handshake statistics
    private var tlsHandshakeSuccess: Int = 0
    private var tlsHandshakeFailed: Int = 0

    /// Command parsing errors
    private var commandParseErrors: Int = 0

    /// Last metrics emission time
    private var lastEmissionTime: Date

    /// Metrics emission interval (seconds)
    private let emissionInterval: TimeInterval

    /// Maximum samples to keep for percentile calculations
    private let maxSamples = 10000

    /// Initialize a metrics collector
    /// - Parameter emissionInterval: How often to emit aggregated metrics (default: 60 seconds)
    public init(emissionInterval: TimeInterval = 60.0) {
        self.emissionInterval = emissionInterval
        self.lastEmissionTime = Date()
    }

    // MARK: - Connection Metrics

    /// Record a newly accepted connection
    /// - Parameter latency: Time from accept() call to connection ready (in seconds)
    public func recordConnectionAccepted(latency: TimeInterval) {
        activeConnections += 1
        totalConnectionsAccepted += 1
        acceptLatencySamples.append(latency)

        // Trim samples if needed
        if acceptLatencySamples.count > maxSamples {
            acceptLatencySamples.removeFirst(acceptLatencySamples.count - maxSamples)
        }
    }

    /// Record a closed connection
    public func recordConnectionClosed() {
        activeConnections = max(0, activeConnections - 1)
    }

    /// Get current active connection count
    public func getActiveConnections() -> Int {
        return activeConnections
    }

    // MARK: - Message Metrics

    /// Record a processed message
    /// - Parameters:
    ///   - size: Message size in bytes
    ///   - latency: Processing latency in seconds (from MAIL FROM to completion)
    public func recordMessageProcessed(size: Int, latency: TimeInterval = 0) {
        messagesProcessed += 1
        bytesTransferred += size

        if latency > 0 {
            messageLatencySamples.append(latency)

            // Trim samples if needed
            if messageLatencySamples.count > maxSamples {
                messageLatencySamples.removeFirst(messageLatencySamples.count - maxSamples)
            }
        }
    }

    // MARK: - Error Metrics

    /// Record an error occurrence
    /// - Parameter errorType: Type of error (e.g., "timeout", "parse_error", "tls_handshake")
    public func recordError(errorType: String) {
        errorCounts[errorType, default: 0] += 1
    }

    /// Record TLS handshake result
    /// - Parameter success: Whether the handshake succeeded
    public func recordTLSHandshake(success: Bool) {
        if success {
            tlsHandshakeSuccess += 1
        } else {
            tlsHandshakeFailed += 1
            recordError(errorType: "tls_handshake_failed")
        }
    }

    /// Record a command parsing error
    public func recordCommandParseError() {
        commandParseErrors += 1
        recordError(errorType: "command_parse_error")
    }

    // MARK: - Metrics Emission

    /// Check if metrics should be emitted and emit if ready
    /// - Returns: true if metrics were emitted
    @discardableResult
    public func maybeEmitMetrics() -> Bool {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastEmissionTime)

        if elapsed >= emissionInterval {
            emitMetrics()
            lastEmissionTime = now
            return true
        }

        return false
    }

    /// Emit current metrics as structured JSON
    public func emitMetrics() {
        let metrics: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "type": "smtp_metrics",
            "connections": [
                "active": activeConnections,
                "total_accepted": totalConnectionsAccepted,
                "accept_latency_p50": percentile(acceptLatencySamples, 0.50),
                "accept_latency_p99": percentile(acceptLatencySamples, 0.99),
                "accept_latency_p999": percentile(acceptLatencySamples, 0.999),
                "accept_latency_max": acceptLatencySamples.max() ?? 0
            ],
            "messages": [
                "total_processed": messagesProcessed,
                "bytes_transferred": bytesTransferred,
                "processing_latency_p50": percentile(messageLatencySamples, 0.50),
                "processing_latency_p99": percentile(messageLatencySamples, 0.99),
                "processing_latency_max": messageLatencySamples.max() ?? 0,
                "throughput_msgs_per_sec": calculateThroughput()
            ],
            "tls": [
                "handshakes_success": tlsHandshakeSuccess,
                "handshakes_failed": tlsHandshakeFailed
            ],
            "errors": errorCounts
        ]

        // Emit as JSON to stdout
        if let jsonData = try? JSONSerialization.data(withJSONObject: metrics, options: [.sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[METRICS] \(jsonString)")
        }
    }

    /// Reset metrics after emission (for rate calculations)
    public func resetCounters() {
        // Keep running totals but reset samples for percentiles
        acceptLatencySamples.removeAll()
        messageLatencySamples.removeAll()
    }

    // MARK: - Private Helpers

    /// Calculate percentile from samples
    /// - Parameters:
    ///   - samples: Array of time intervals
    ///   - percentile: Percentile to calculate (0.0 to 1.0)
    /// - Returns: Percentile value in milliseconds
    private func percentile(_ samples: [TimeInterval], _ percentile: Double) -> Double {
        guard !samples.isEmpty else { return 0 }

        let sorted = samples.sorted()
        let index = Int(Double(sorted.count) * percentile)
        let clampedIndex = min(index, sorted.count - 1)

        // Return in milliseconds
        return sorted[clampedIndex] * 1000.0
    }

    /// Calculate throughput in messages per second
    private func calculateThroughput() -> Double {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastEmissionTime)

        guard elapsed > 0 else { return 0 }

        return Double(messagesProcessed) / elapsed
    }
}
