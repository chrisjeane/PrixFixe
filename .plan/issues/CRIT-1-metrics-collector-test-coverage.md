# CRIT-1: MetricsCollector Has Zero Test Coverage

**Created:** 2025-11-28
**Severity:** CRITICAL
**Status:** OPEN
**Blocks:** v0.2.1 release
**Component:** PrixFixeCore/Metrics.swift
**Related:** V0.2.1-RELEASE-REVIEW.md

---

## Problem

The MetricsCollector actor, which is the primary feature addition in v0.2.1, has no automated test coverage. This is a **critical release blocker** because:

1. Production monitoring infrastructure must be rigorously tested
2. Incorrect metrics could lead to wrong operational decisions
3. Bugs could cause memory leaks, incorrect alerts, or monitoring failures
4. No validation that percentile calculations are correct
5. No verification that JSON output is parseable

**Current State:**
- Metrics.swift: 235 lines of new code
- Test coverage: 0%
- Tests files mentioning "Metrics": 0

**Impact:**
- **Production Risk:** HIGH - Could emit incorrect metrics leading to bad operational decisions
- **Reliability:** UNKNOWN - No verification of correctness
- **Memory Safety:** UNKNOWN - Sample limiting not tested (potential leak)

---

## Required Test Coverage

### Unit Tests for MetricsCollector

Create: `Tests/PrixFixeCoreTests/MetricsCollectorTests.swift`

#### 1. Basic Functionality Tests

```swift
@Suite("MetricsCollector Basic Functionality")
struct MetricsCollectorBasicTests {
    @Test("Record connection accepted increments counters")
    func testRecordConnectionAccepted() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordConnectionAccepted(latency: 0.002)

        let activeConnections = await metrics.getActiveConnections()
        #expect(activeConnections == 2)
    }

    @Test("Record connection closed decrements counter")
    func testRecordConnectionClosed() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordConnectionClosed()

        let activeConnections = await metrics.getActiveConnections()
        #expect(activeConnections == 0)
    }

    @Test("Connection closed does not go below zero")
    func testConnectionClosedNeverNegative() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionClosed()
        await metrics.recordConnectionClosed()

        let activeConnections = await metrics.getActiveConnections()
        #expect(activeConnections == 0)
    }

    @Test("Record message processed tracks size and count")
    func testRecordMessageProcessed() async {
        let metrics = MetricsCollector()

        await metrics.recordMessageProcessed(size: 1024)
        await metrics.recordMessageProcessed(size: 2048)

        // Verify via emitMetrics output
        await metrics.emitMetrics()
        // Check JSON contains messages.total_processed = 2
        // Check JSON contains messages.bytes_transferred = 3072
    }

    @Test("Record error increments error counts")
    func testRecordError() async {
        let metrics = MetricsCollector()

        await metrics.recordError(errorType: "timeout")
        await metrics.recordError(errorType: "timeout")
        await metrics.recordError(errorType: "parse_error")

        // Verify via emitMetrics output
        await metrics.emitMetrics()
        // Check JSON contains errors.timeout = 2
        // Check JSON contains errors.parse_error = 1
    }

    @Test("Record TLS handshake tracks success and failure")
    func testRecordTLSHandshake() async {
        let metrics = MetricsCollector()

        await metrics.recordTLSHandshake(success: true)
        await metrics.recordTLSHandshake(success: true)
        await metrics.recordTLSHandshake(success: false)

        // Verify via emitMetrics output
        await metrics.emitMetrics()
        // Check JSON contains tls.handshakes_success = 2
        // Check JSON contains tls.handshakes_failed = 1
        // Check JSON contains errors.tls_handshake_failed = 1
    }
}
```

#### 2. Percentile Calculation Tests

```swift
@Suite("MetricsCollector Percentile Calculations")
struct MetricsCollectorPercentileTests {
    @Test("Percentile calculation with known samples")
    func testPercentileCalculation() async {
        let metrics = MetricsCollector()

        // Record 100 samples with known distribution
        for i in 1...100 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000.0)
        }

        // TODO: Capture JSON output and verify:
        // P50 should be ~50ms
        // P99 should be ~99ms
        // P999 should be ~100ms (clamped to max)
        // Max should be 100ms
    }

    @Test("Percentile calculation with empty samples")
    func testPercentileWithEmptySamples() async {
        let metrics = MetricsCollector()

        await metrics.emitMetrics()
        // Verify all percentiles are 0
    }

    @Test("Percentile calculation with single sample")
    func testPercentileWithSingleSample() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.005)

        // Verify P50, P99, P999 all equal 5ms
    }
}
```

#### 3. Sample Limiting Tests

```swift
@Suite("MetricsCollector Sample Limiting")
struct MetricsCollectorSampleLimitingTests {
    @Test("Accept latency samples limited to 10000")
    func testAcceptLatencySampleLimiting() async {
        let metrics = MetricsCollector()

        // Record 15,000 samples
        for i in 1...15000 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000.0)
        }

        // TODO: Verify only most recent 10,000 samples retained
        // Oldest 5,000 samples should be discarded
    }

    @Test("Message latency samples limited to 10000")
    func testMessageLatencySampleLimiting() async {
        let metrics = MetricsCollector()

        // Record 15,000 samples
        for i in 1...15000 {
            await metrics.recordMessageProcessed(size: 1024, latency: Double(i) / 1000.0)
        }

        // TODO: Verify only most recent 10,000 samples retained
    }
}
```

#### 4. Metrics Emission Tests

```swift
@Suite("MetricsCollector Emission")
struct MetricsCollectorEmissionTests {
    @Test("emitMetrics produces valid JSON")
    func testEmitMetricsValidJSON() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordMessageProcessed(size: 1024)

        // TODO: Capture stdout
        await metrics.emitMetrics()
        // Parse JSON and verify structure
    }

    @Test("maybeEmitMetrics respects interval")
    func testMaybeEmitMetricsInterval() async {
        let metrics = MetricsCollector(emissionInterval: 1.0)

        // Should not emit immediately
        let emitted1 = await metrics.maybeEmitMetrics()
        #expect(emitted1 == false)

        // Wait for interval
        try? await Task.sleep(for: .seconds(1.1))

        // Should emit now
        let emitted2 = await metrics.maybeEmitMetrics()
        #expect(emitted2 == true)
    }

    @Test("JSON output contains all expected fields")
    func testJSONOutputStructure() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordMessageProcessed(size: 1024, latency: 0.005)
        await metrics.recordTLSHandshake(success: true)
        await metrics.recordError(errorType: "test_error")

        // TODO: Capture and parse JSON
        await metrics.emitMetrics()

        // Verify required fields:
        // - timestamp (ISO8601)
        // - type = "smtp_metrics"
        // - connections.active
        // - connections.total_accepted
        // - connections.accept_latency_p50
        // - connections.accept_latency_p99
        // - connections.accept_latency_p999
        // - connections.accept_latency_max
        // - messages.total_processed
        // - messages.bytes_transferred
        // - messages.processing_latency_p50
        // - messages.processing_latency_p99
        // - messages.processing_latency_max
        // - messages.throughput_msgs_per_sec
        // - tls.handshakes_success
        // - tls.handshakes_failed
        // - errors (dictionary)
    }
}
```

#### 5. Throughput Calculation Tests

```swift
@Suite("MetricsCollector Throughput")
struct MetricsCollectorThroughputTests {
    @Test("Throughput calculation is correct")
    func testThroughputCalculation() async {
        let metrics = MetricsCollector(emissionInterval: 1.0)

        // Record 100 messages
        for _ in 1...100 {
            await metrics.recordMessageProcessed(size: 1024)
        }

        // Wait 1 second
        try? await Task.sleep(for: .seconds(1.0))

        // Throughput should be ~100 msg/sec
        // TODO: Verify via JSON output
    }

    @Test("Throughput handles zero elapsed time")
    func testThroughputZeroElapsed() async {
        let metrics = MetricsCollector()

        await metrics.recordMessageProcessed(size: 1024)

        // Emit immediately (elapsed ~0)
        await metrics.emitMetrics()

        // Throughput should be 0 or very high (not crash)
    }
}
```

### Integration Tests with SMTPServer

Create: `Tests/PrixFixeCoreTests/MetricsIntegrationTests.swift`

```swift
@Suite("Metrics Integration with SMTPServer")
struct MetricsIntegrationTests {
    @Test("SMTPServer with metrics enabled records connections")
    func testServerMetricsIntegration() async throws {
        let config = ServerConfiguration(
            domain: "test.local",
            port: 0  // Ephemeral port
        )

        let server = SMTPServer(
            configuration: config,
            enableMetrics: true,
            metricsInterval: 1.0
        )

        try await server.start()

        // TODO: Connect client, send message
        // Verify metrics are recorded
        // Check metrics emission

        await server.stop()
    }

    @Test("SMTPServer with metrics disabled has no overhead")
    func testServerNoMetrics() async throws {
        let config = ServerConfiguration(
            domain: "test.local",
            port: 0
        )

        let server = SMTPServer(
            configuration: config,
            enableMetrics: false  // Disabled
        )

        try await server.start()

        // TODO: Verify no metrics emitted
        // Verify no performance impact

        await server.stop()
    }
}
```

---

## Acceptance Criteria

- [ ] All MetricsCollector public methods have unit tests
- [ ] Percentile calculation validated with known test data
- [ ] Sample limiting (10,000 max) verified
- [ ] JSON output structure validated
- [ ] JSON output is parseable by standard JSON parser
- [ ] Timestamp format is valid ISO8601
- [ ] All metric fields populated correctly
- [ ] maybeEmitMetrics() interval behavior tested
- [ ] Throughput calculation verified
- [ ] Edge cases handled (empty samples, zero elapsed time, etc.)
- [ ] Integration with SMTPServer tested
- [ ] Metrics disabled mode (enableMetrics=false) tested
- [ ] Actor isolation behavior verified (concurrent access safe)
- [ ] Test coverage for Metrics.swift > 90%

---

## Implementation Notes

### Capturing stdout for JSON Validation

The `emitMetrics()` method prints to stdout. Tests need to capture this output:

```swift
// Possible approaches:
// 1. Refactor emitMetrics to return JSON string (breaking change)
// 2. Use XCTestExpectation with custom logger
// 3. Redirect stdout during test
// 4. Add internal method that returns JSON without printing
```

**Recommendation:** Add internal method `func getMetricsJSON() -> [String: Any]` for testing, keep `emitMetrics()` for production.

### Test Data Generation

Create helper to generate realistic test data:

```swift
struct MetricsTestHelper {
    static func generateLatencySamples(count: Int, distribution: Distribution) -> [TimeInterval]

    enum Distribution {
        case uniform(min: TimeInterval, max: TimeInterval)
        case normal(mean: TimeInterval, stddev: TimeInterval)
        case realistic  // Simulates real-world latency distribution
    }
}
```

---

## Effort Estimate

- **Unit tests (basic):** 2 hours
- **Percentile tests:** 1 hour
- **Sample limiting tests:** 1 hour
- **JSON emission tests:** 1 hour
- **Integration tests:** 1 hour
- **Edge case tests:** 0.5 hours
- **Test helpers:** 0.5 hours

**Total:** 6-7 hours

---

## Priority

**CRITICAL - BLOCKS RELEASE**

This is the highest priority issue for v0.2.1. The primary feature of this release cannot ship without comprehensive test coverage.

---

## Related Issues

- None

---

## Resolution

**Status:** OPEN
**Assigned:** TBD
**Target:** Before v0.2.1 release
**Estimated Effort:** 6-7 hours
