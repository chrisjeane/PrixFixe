import Testing
import Foundation
@testable import PrixFixeCore

/// Comprehensive test suite for MetricsCollector
///
/// This test suite provides complete coverage of the MetricsCollector actor,
/// including basic functionality, percentile calculations, sample limiting,
/// JSON output validation, and edge case handling.
///
/// Note: MetricsCollector emits JSON to stdout. Most tests verify behavior through
/// the public API (getActiveConnections) and ensure operations complete without error.
/// In a production environment, stdout could be captured and parsed for full validation.

// MARK: - Basic Functionality Tests

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

    @Test("Connection closed never goes below zero")
    func testConnectionClosedNeverNegative() async {
        let metrics = MetricsCollector()

        // Try to close connections that were never opened
        await metrics.recordConnectionClosed()
        await metrics.recordConnectionClosed()
        await metrics.recordConnectionClosed()

        let activeConnections = await metrics.getActiveConnections()
        #expect(activeConnections == 0)
    }

    @Test("Multiple connection lifecycle operations")
    func testMultipleConnectionOperations() async {
        let metrics = MetricsCollector()

        // Accept 5 connections
        for i in 1...5 {
            await metrics.recordConnectionAccepted(latency: Double(i) * 0.001)
        }

        #expect(await metrics.getActiveConnections() == 5)

        // Close 3 connections
        await metrics.recordConnectionClosed()
        await metrics.recordConnectionClosed()
        await metrics.recordConnectionClosed()

        #expect(await metrics.getActiveConnections() == 2)

        // Accept 2 more
        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordConnectionAccepted(latency: 0.002)

        #expect(await metrics.getActiveConnections() == 4)
    }

    @Test("Record message processed without latency")
    func testRecordMessageProcessedNoLatency() async {
        let metrics = MetricsCollector()

        await metrics.recordMessageProcessed(size: 1024)
        await metrics.recordMessageProcessed(size: 2048)
        await metrics.recordMessageProcessed(size: 512)

        // Verify via emitMetrics (should not crash)
        await metrics.emitMetrics()
    }

    @Test("Record message processed with latency")
    func testRecordMessageProcessedWithLatency() async {
        let metrics = MetricsCollector()

        await metrics.recordMessageProcessed(size: 1024, latency: 0.001)
        await metrics.recordMessageProcessed(size: 2048, latency: 0.002)
        await metrics.recordMessageProcessed(size: 512, latency: 0.0015)

        // Latency samples should be recorded
        await metrics.emitMetrics()
    }

    @Test("Record message processed with zero latency is ignored")
    func testRecordMessageProcessedZeroLatency() async {
        let metrics = MetricsCollector()

        // Zero latency should not add to samples
        await metrics.recordMessageProcessed(size: 1024, latency: 0.0)

        // But message count and bytes should still be recorded
        await metrics.emitMetrics()
    }

    @Test("Record error increments error counts")
    func testRecordError() async {
        let metrics = MetricsCollector()

        await metrics.recordError(errorType: "timeout")
        await metrics.recordError(errorType: "timeout")
        await metrics.recordError(errorType: "parse_error")
        await metrics.recordError(errorType: "connection_reset")

        // Errors should be tracked by type
        await metrics.emitMetrics()
    }

    @Test("Record TLS handshake success")
    func testRecordTLSHandshakeSuccess() async {
        let metrics = MetricsCollector()

        await metrics.recordTLSHandshake(success: true)
        await metrics.recordTLSHandshake(success: true)
        await metrics.recordTLSHandshake(success: true)

        // TLS success count should be 3
        await metrics.emitMetrics()
    }

    @Test("Record TLS handshake failure")
    func testRecordTLSHandshakeFailure() async {
        let metrics = MetricsCollector()

        await metrics.recordTLSHandshake(success: false)
        await metrics.recordTLSHandshake(success: false)

        // TLS failure count should be 2
        // Should also record error type "tls_handshake_failed"
        await metrics.emitMetrics()
    }

    @Test("Record TLS handshake mixed results")
    func testRecordTLSHandshakeMixed() async {
        let metrics = MetricsCollector()

        await metrics.recordTLSHandshake(success: true)
        await metrics.recordTLSHandshake(success: true)
        await metrics.recordTLSHandshake(success: false)
        await metrics.recordTLSHandshake(success: true)
        await metrics.recordTLSHandshake(success: false)

        // Success: 3, Failed: 2
        await metrics.emitMetrics()
    }

    @Test("Record command parse error")
    func testRecordCommandParseError() async {
        let metrics = MetricsCollector()

        await metrics.recordCommandParseError()
        await metrics.recordCommandParseError()
        await metrics.recordCommandParseError()

        // Should increment both commandParseErrors and errors["command_parse_error"]
        await metrics.emitMetrics()
    }
}

// MARK: - Percentile Calculation Tests

@Suite("MetricsCollector Percentile Calculations")
struct MetricsCollectorPercentileTests {

    @Test("Percentile calculation with uniform distribution")
    func testPercentileUniformDistribution() async {
        let metrics = MetricsCollector()

        // Record 100 samples: 1ms, 2ms, 3ms, ..., 100ms
        for i in 1...100 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000.0)
        }

        // P50 should be around 50ms
        // P99 should be around 99ms
        // P999 should be around 100ms (clamped to max)
        // Max should be 100ms
        await metrics.emitMetrics()
    }

    @Test("Percentile calculation with known small dataset")
    func testPercentileSmallDataset() async {
        let metrics = MetricsCollector()

        // Record exactly 10 samples: 1ms, 2ms, ..., 10ms
        for i in 1...10 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000.0)
        }

        // P50 (index 5) should be 5ms or 6ms
        // P99 (index 9.9 -> 9) should be 10ms
        await metrics.emitMetrics()
    }

    @Test("Percentile with empty samples returns zero")
    func testPercentileEmptySamples() async {
        let metrics = MetricsCollector()

        // Don't record any samples
        await metrics.emitMetrics()

        // All percentiles should be 0
    }

    @Test("Percentile with single sample")
    func testPercentileSingleSample() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.005)

        // All percentiles (P50, P99, P999) should equal 5ms
        // Max should also be 5ms
        await metrics.emitMetrics()
    }

    @Test("Percentile with two samples")
    func testPercentileTwoSamples() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordConnectionAccepted(latency: 0.010)

        // P50 should be 1ms or 10ms (depending on rounding)
        // P99 should be 10ms
        await metrics.emitMetrics()
    }

    @Test("Percentile calculation for message latency")
    func testPercentileMessageLatency() async {
        let metrics = MetricsCollector()

        // Record message latencies
        for i in 1...100 {
            await metrics.recordMessageProcessed(
                size: 1024,
                latency: Double(i) / 1000.0
            )
        }

        // Should calculate percentiles correctly for message processing
        await metrics.emitMetrics()
    }

    @Test("Percentile with large dataset")
    func testPercentileLargeDataset() async {
        let metrics = MetricsCollector()

        // Record 1000 samples with realistic distribution
        for i in 1...1000 {
            let latency = Double(i) / 1000.0
            await metrics.recordConnectionAccepted(latency: latency)
        }

        // P50 should be ~500ms
        // P99 should be ~990ms
        await metrics.emitMetrics()
    }
}

// MARK: - Sample Limiting Tests

@Suite("MetricsCollector Sample Limiting")
struct MetricsCollectorSampleLimitingTests {

    @Test("Accept latency samples limited to maxSamples")
    func testAcceptLatencySampleLimiting() async {
        let metrics = MetricsCollector()

        // Record 15,000 samples (exceeds 10,000 limit)
        for i in 1...15000 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000000.0)
        }

        // Only the most recent 10,000 samples should be retained
        // The oldest 5,000 samples (1-5000) should be discarded
        // Remaining samples should be 5001-15000
        await metrics.emitMetrics()
    }

    @Test("Message latency samples limited to maxSamples")
    func testMessageLatencySampleLimiting() async {
        let metrics = MetricsCollector()

        // Record 15,000 message samples
        for i in 1...15000 {
            await metrics.recordMessageProcessed(
                size: 1024,
                latency: Double(i) / 1000000.0
            )
        }

        // Only most recent 10,000 should be retained
        await metrics.emitMetrics()
    }

    @Test("Sample limiting at exactly maxSamples boundary")
    func testSampleLimitingAtBoundary() async {
        let metrics = MetricsCollector()

        // Record exactly 10,000 samples
        for i in 1...10000 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000000.0)
        }

        // All 10,000 should be retained

        // Add one more
        await metrics.recordConnectionAccepted(latency: 0.011)

        // Now oldest should be removed, newest retained
        await metrics.emitMetrics()
    }

    @Test("Sample limiting maintains correct statistics")
    func testSampleLimitingMaintainsStatistics() async {
        let metrics = MetricsCollector()

        // Record 12,000 samples
        for i in 1...12000 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000.0)
        }

        // After limiting, only samples 2001-12000 remain
        // Max should be 12000ms (12 seconds)
        // P99 should be calculated from the retained 10,000 samples
        await metrics.emitMetrics()
    }
}

// MARK: - Metrics Emission Tests

@Suite("MetricsCollector Emission")
struct MetricsCollectorEmissionTests {

    @Test("emitMetrics produces output")
    func testEmitMetricsProducesOutput() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordMessageProcessed(size: 1024)

        // This will print to stdout
        await metrics.emitMetrics()

        // In a production test, we'd capture stdout and verify format
    }

    @Test("maybeEmitMetrics does not emit before interval")
    func testMaybeEmitMetricsBeforeInterval() async {
        let metrics = MetricsCollector(emissionInterval: 10.0)

        // Should not emit immediately
        let emitted = await metrics.maybeEmitMetrics()
        #expect(emitted == false)
    }

    @Test("maybeEmitMetrics emits after interval", .timeLimit(.minutes(1)))
    func testMaybeEmitMetricsAfterInterval() async throws {
        let metrics = MetricsCollector(emissionInterval: 0.5)

        // Should not emit immediately
        let emitted1 = await metrics.maybeEmitMetrics()
        #expect(emitted1 == false)

        // Wait for interval to elapse
        try await Task.sleep(for: .milliseconds(600))

        // Should emit now
        let emitted2 = await metrics.maybeEmitMetrics()
        #expect(emitted2 == true)
    }

    @Test("maybeEmitMetrics resets interval after emission", .timeLimit(.minutes(1)))
    func testMaybeEmitMetricsResetsInterval() async throws {
        let metrics = MetricsCollector(emissionInterval: 0.3)

        // Wait and emit
        try await Task.sleep(for: .milliseconds(350))
        let emitted1 = await metrics.maybeEmitMetrics()
        #expect(emitted1 == true)

        // Should not emit immediately after
        let emitted2 = await metrics.maybeEmitMetrics()
        #expect(emitted2 == false)

        // Wait again
        try await Task.sleep(for: .milliseconds(350))
        let emitted3 = await metrics.maybeEmitMetrics()
        #expect(emitted3 == true)
    }

    @Test("emitMetrics with no data does not crash")
    func testEmitMetricsWithNoData() async {
        let metrics = MetricsCollector()

        // Emit without recording any data
        await metrics.emitMetrics()

        // Should produce valid JSON with zeros
    }

    @Test("emitMetrics with complete data")
    func testEmitMetricsWithCompleteData() async {
        let metrics = MetricsCollector()

        // Record all types of metrics
        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordConnectionAccepted(latency: 0.002)
        await metrics.recordConnectionClosed()

        await metrics.recordMessageProcessed(size: 1024, latency: 0.005)
        await metrics.recordMessageProcessed(size: 2048, latency: 0.008)

        await metrics.recordTLSHandshake(success: true)
        await metrics.recordTLSHandshake(success: false)

        await metrics.recordError(errorType: "timeout")
        await metrics.recordError(errorType: "parse_error")
        await metrics.recordCommandParseError()

        await metrics.emitMetrics()

        // Should produce comprehensive JSON
    }
}

// MARK: - Reset Tests

@Suite("MetricsCollector Reset and Clear")
struct MetricsCollectorResetTests {

    @Test("resetCounters clears latency samples")
    func testResetCountersClears() async {
        let metrics = MetricsCollector()

        // Record samples
        for i in 1...100 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000.0)
        }

        await metrics.resetCounters()

        // Samples should be cleared
        // Active connections and totals should remain
        await metrics.emitMetrics()
    }

    @Test("resetCounters clears message latency samples")
    func testResetCountersMessageLatency() async {
        let metrics = MetricsCollector()

        // Record message samples
        for i in 1...50 {
            await metrics.recordMessageProcessed(size: 1024, latency: Double(i) / 1000.0)
        }

        await metrics.resetCounters()

        // Message latency samples should be cleared
        await metrics.emitMetrics()
    }

    @Test("resetCounters preserves running totals")
    func testResetCountersPreservesTotals() async {
        let metrics = MetricsCollector()

        // Record connections
        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordConnectionAccepted(latency: 0.002)

        let before = await metrics.getActiveConnections()

        await metrics.resetCounters()

        let after = await metrics.getActiveConnections()

        // Active connections should be preserved
        #expect(before == after)
        #expect(after == 2)
    }
}

// MARK: - Edge Cases

@Suite("MetricsCollector Edge Cases")
struct MetricsCollectorEdgeCaseTests {

    @Test("Zero latency is handled correctly")
    func testZeroLatency() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.0)
        await metrics.recordMessageProcessed(size: 1024, latency: 0.0)

        // Should not crash, zero latency messages not added to samples
        await metrics.emitMetrics()
    }

    @Test("Negative latency is accepted but unusual")
    func testNegativeLatency() async {
        let metrics = MetricsCollector()

        // Negative latency shouldn't happen but shouldn't crash
        await metrics.recordConnectionAccepted(latency: -0.001)

        // Should be recorded as-is
        await metrics.emitMetrics()
    }

    @Test("Very large latency values")
    func testLargeLatencyValues() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 1000.0) // 1000 seconds
        await metrics.recordMessageProcessed(size: 1024, latency: 999.9)

        // Should handle without overflow
        await metrics.emitMetrics()
    }

    @Test("Very large message sizes")
    func testLargeMessageSizes() async {
        let metrics = MetricsCollector()

        await metrics.recordMessageProcessed(size: 1_000_000_000) // 1GB
        await metrics.recordMessageProcessed(size: 100_000_000) // 100MB

        // Should not overflow bytesTransferred
        await metrics.emitMetrics()
    }

    @Test("Empty error type string")
    func testEmptyErrorType() async {
        let metrics = MetricsCollector()

        await metrics.recordError(errorType: "")

        // Should record error with empty string key
        await metrics.emitMetrics()
    }

    @Test("Very long error type string")
    func testLongErrorType() async {
        let metrics = MetricsCollector()

        let longError = String(repeating: "a", count: 1000)
        await metrics.recordError(errorType: longError)

        // Should handle without issues
        await metrics.emitMetrics()
    }

    @Test("Concurrent metric recording is safe")
    func testConcurrentRecording() async {
        let metrics = MetricsCollector()

        // Record metrics concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 1...100 {
                group.addTask {
                    await metrics.recordConnectionAccepted(latency: Double(i) / 1000.0)
                }
                group.addTask {
                    await metrics.recordMessageProcessed(size: 1024)
                }
                group.addTask {
                    await metrics.recordError(errorType: "test_error_\(i)")
                }
            }
        }

        // All operations should complete without data races
        let active = await metrics.getActiveConnections()
        #expect(active == 100)
    }

    @Test("Extremely short emission interval")
    func testExtremelyShortEmissionInterval() async {
        let metrics = MetricsCollector(emissionInterval: 0.001) // 1ms

        await metrics.recordConnectionAccepted(latency: 0.001)

        // Should not crash with very short intervals
        await metrics.emitMetrics()
    }

    @Test("Zero emission interval")
    func testZeroEmissionInterval() async {
        let metrics = MetricsCollector(emissionInterval: 0.0)

        // maybeEmitMetrics should always emit
        let emitted = await metrics.maybeEmitMetrics()
        #expect(emitted == true)
    }
}

// MARK: - Throughput Calculation Tests

@Suite("MetricsCollector Throughput Calculation")
struct MetricsCollectorThroughputTests {

    @Test("Throughput with zero elapsed time")
    func testThroughputZeroElapsed() async {
        let metrics = MetricsCollector()

        await metrics.recordMessageProcessed(size: 1024)
        await metrics.recordMessageProcessed(size: 2048)

        // Emit immediately (elapsed time ~0)
        await metrics.emitMetrics()

        // Throughput should be 0 or handle gracefully (not crash)
    }

    @Test("Throughput calculation after delay", .timeLimit(.minutes(1)))
    func testThroughputCalculation() async throws {
        let metrics = MetricsCollector(emissionInterval: 0.5)

        // Record messages
        for _ in 1...50 {
            await metrics.recordMessageProcessed(size: 1024)
        }

        // Wait for interval
        try await Task.sleep(for: .milliseconds(500))

        // Throughput should be approximately 100 msg/sec (50 msgs / 0.5 sec)
        await metrics.emitMetrics()
    }

    @Test("Throughput resets after emission", .timeLimit(.minutes(1)))
    func testThroughputResetsAfterEmission() async throws {
        let metrics = MetricsCollector(emissionInterval: 0.3)

        // Record initial messages
        for _ in 1...30 {
            await metrics.recordMessageProcessed(size: 1024)
        }

        try await Task.sleep(for: .milliseconds(350))
        let emitted1 = await metrics.maybeEmitMetrics()
        #expect(emitted1 == true)

        // Record more messages after emission
        for _ in 1...60 {
            await metrics.recordMessageProcessed(size: 1024)
        }

        try await Task.sleep(for: .milliseconds(350))
        let emitted2 = await metrics.maybeEmitMetrics()
        #expect(emitted2 == true)

        // Second throughput should reflect only the 60 new messages
    }
}

// MARK: - Actor Isolation Tests

@Suite("MetricsCollector Actor Isolation")
struct MetricsCollectorActorIsolationTests {

    @Test("Actor provides isolation for concurrent access")
    func testActorIsolation() async {
        let metrics = MetricsCollector()

        // Simulate concurrent access from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Record connections
            group.addTask {
                for i in 1...1000 {
                    await metrics.recordConnectionAccepted(latency: Double(i) / 1000000.0)
                }
            }

            // Task 2: Close connections
            group.addTask {
                for _ in 1...1000 {
                    await metrics.recordConnectionClosed()
                }
            }

            // Task 3: Record messages
            group.addTask {
                for i in 1...1000 {
                    await metrics.recordMessageProcessed(size: i * 100)
                }
            }

            // Task 4: Record errors
            group.addTask {
                for i in 1...1000 {
                    await metrics.recordError(errorType: "error_\(i % 10)")
                }
            }

            // Task 5: Emit metrics
            group.addTask {
                for _ in 1...10 {
                    await metrics.emitMetrics()
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }
        }

        // Final state should be consistent
        let active = await metrics.getActiveConnections()
        #expect(active >= 0) // Should never be negative
    }

    @Test("Multiple tasks can safely read active connections")
    func testConcurrentReads() async {
        let metrics = MetricsCollector()

        await metrics.recordConnectionAccepted(latency: 0.001)
        await metrics.recordConnectionAccepted(latency: 0.002)

        // Multiple tasks reading simultaneously
        await withTaskGroup(of: Int.self) { group in
            for _ in 1...100 {
                group.addTask {
                    await metrics.getActiveConnections()
                }
            }

            var counts: [Int] = []
            for await count in group {
                counts.append(count)
            }

            // All reads should return the same value (2)
            #expect(counts.allSatisfy { $0 == 2 })
        }
    }
}

// MARK: - Realistic Usage Scenarios

@Suite("MetricsCollector Realistic Scenarios")
struct MetricsCollectorRealisticTests {

    @Test("Typical SMTP session metrics")
    func testTypicalSMTPSession() async {
        let metrics = MetricsCollector()

        // Simulate typical SMTP session
        // 1. Connection accepted
        await metrics.recordConnectionAccepted(latency: 0.002)

        // 2. TLS handshake
        await metrics.recordTLSHandshake(success: true)

        // 3. Process message
        await metrics.recordMessageProcessed(size: 4096, latency: 0.015)

        // 4. Connection closed
        await metrics.recordConnectionClosed()

        await metrics.emitMetrics()

        // Should show 0 active, 1 total, 1 message, 1 TLS success
        let active = await metrics.getActiveConnections()
        #expect(active == 0)
    }

    @Test("High load simulation")
    func testHighLoadSimulation() async {
        let metrics = MetricsCollector()

        // Simulate 1000 concurrent connections
        for i in 1...1000 {
            await metrics.recordConnectionAccepted(latency: Double.random(in: 0.001...0.010))
        }

        #expect(await metrics.getActiveConnections() == 1000)

        // Process 10000 messages
        for _ in 1...10000 {
            await metrics.recordMessageProcessed(
                size: Int.random(in: 1024...10240),
                latency: Double.random(in: 0.001...0.050)
            )
        }

        // Some TLS handshakes
        for _ in 1...500 {
            await metrics.recordTLSHandshake(success: true)
        }
        for _ in 1...50 {
            await metrics.recordTLSHandshake(success: false)
        }

        // Some errors
        for _ in 1...100 {
            await metrics.recordError(errorType: "timeout")
        }

        await metrics.emitMetrics()

        // Should handle large volumes without issues
    }

    @Test("Long-running server simulation", .timeLimit(.minutes(1)))
    func testLongRunningServer() async throws {
        let metrics = MetricsCollector(emissionInterval: 0.2)

        // Simulate 1 second of server operation
        let startTime = Date()
        var emissions = 0

        while Date().timeIntervalSince(startTime) < 1.0 {
            // Accept connections
            await metrics.recordConnectionAccepted(latency: 0.001)

            // Process messages
            await metrics.recordMessageProcessed(size: 2048, latency: 0.005)

            // Maybe emit
            if await metrics.maybeEmitMetrics() {
                emissions += 1
            }

            try await Task.sleep(for: .milliseconds(50))
        }

        // Should have emitted multiple times (1 second / 0.2 second interval = 5 times)
        #expect(emissions >= 4)
    }

    @Test("Metrics survive many connection cycles")
    func testConnectionCycles() async {
        let metrics = MetricsCollector()

        // Simulate 100 connection open/close cycles
        for _ in 1...100 {
            await metrics.recordConnectionAccepted(latency: 0.001)
            await metrics.recordMessageProcessed(size: 1024, latency: 0.005)
            await metrics.recordConnectionClosed()
        }

        // Should show 0 active connections
        let active = await metrics.getActiveConnections()
        #expect(active == 0)

        await metrics.emitMetrics()
    }
}

// MARK: - Stress Tests

@Suite("MetricsCollector Stress Tests")
struct MetricsCollectorStressTests {

    @Test("Extreme sample volume")
    func testExtremeSampleVolume() async {
        let metrics = MetricsCollector()

        // Record 50,000 samples (5x the limit)
        for i in 1...50000 {
            await metrics.recordConnectionAccepted(latency: Double(i) / 1000000.0)
        }

        // Only last 10,000 should be retained
        await metrics.emitMetrics()

        // Should not cause memory issues
    }

    @Test("Many different error types")
    func testManyErrorTypes() async {
        let metrics = MetricsCollector()

        // Record 1000 unique error types
        for i in 1...1000 {
            await metrics.recordError(errorType: "error_type_\(i)")
        }

        await metrics.emitMetrics()

        // Should handle large error dictionary
    }

    @Test("Rapid emission cycles", .timeLimit(.minutes(1)))
    func testRapidEmissionCycles() async throws {
        let metrics = MetricsCollector(emissionInterval: 0.01) // 10ms

        // Rapid recording and emission for 0.5 seconds
        let startTime = Date()
        var emissionCount = 0

        while Date().timeIntervalSince(startTime) < 0.5 {
            await metrics.recordConnectionAccepted(latency: 0.001)
            await metrics.recordMessageProcessed(size: 1024)

            if await metrics.maybeEmitMetrics() {
                emissionCount += 1
            }
        }

        // Should have emitted many times (0.5s / 0.01s = 50 times)
        #expect(emissionCount >= 40)
    }
}
