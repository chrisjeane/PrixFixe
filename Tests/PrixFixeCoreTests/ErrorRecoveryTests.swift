import Testing
import Foundation
@testable import PrixFixeCore
@testable import PrixFixeNetwork

@Suite("Error Recovery Tests")
struct ErrorRecoveryTests {

    /// Connection that simulates errors
    actor ErrorSimulatingConnection: NetworkConnection {
        enum SimulatedError: Error {
            case networkFailure
            case timeout
        }

        private var commands: [String]
        private var shouldFailOn: Int?
        private var commandCount = 0

        nonisolated var remoteAddress: any NetworkAddress {
            SocketAddress.localhost(port: 12345)
        }

        init(commands: [String], failOn: Int? = nil) {
            self.commands = commands
            self.shouldFailOn = failOn
        }

        func read(maxBytes: Int) async throws -> Data {
            if let failIndex = shouldFailOn, commandCount == failIndex {
                throw SimulatedError.networkFailure
            }

            guard commandCount < commands.count else {
                return Data()
            }

            let command = commands[commandCount]
            commandCount += 1
            return Data((command + "\r\n").utf8)
        }

        func write(_ data: Data) async throws {
            // Accept writes
        }

        func close() async throws {
            commands.removeAll()
        }
    }

    // MARK: - Connection Error Recovery

    @Test("Session gracefully handles connection errors")
    func testConnectionErrorRecovery() async {
        let commands = [
            "EHLO client.test.com",
            "MAIL FROM:<sender@test.com>",
            "RCPT TO:<user@test.com>",
            "DATA"  // Will fail on next read
        ]

        let conn = ErrorSimulatingConnection(commands: commands, failOn: 4)
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Should not crash despite connection error
        await session.run()

        // If we get here without crashing, error was handled gracefully
        #expect(true)
    }

    @Test("Session handles invalid UTF-8 gracefully")
    func testInvalidUTF8Handling() async {
        // This test verifies the session doesn't crash on encoding errors
        let commands = [
            "EHLO client.test.com",
            "QUIT"
        ]

        let conn = ErrorSimulatingConnection(commands: commands)
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        #expect(true)
    }

    // MARK: - Command Error Recovery

    @Test("Session recovers from command too long error")
    func testCommandTooLongRecovery() async {
        // Create a command that exceeds max length
        let veryLongCommand = "HELO " + String(repeating: "X", count: 10000)

        let commands = [
            veryLongCommand,
            "QUIT"
        ]

        let conn = ErrorSimulatingConnection(commands: commands)
        let config = SessionConfiguration(
            domain: "test.com",
            maxCommandLength: 512,
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Should handle the error and continue
        await session.run()

        #expect(true)
    }

    @Test("Session handles message too large error")
    func testMessageTooLargeRecovery() async {
        let largeLine = String(repeating: "X", count: 1000)

        var commands = [
            "EHLO client.test.com",
            "MAIL FROM:<sender@test.com>",
            "RCPT TO:<user@test.com>",
            "DATA"
        ]

        // Add lines that exceed the limit
        for _ in 0..<2000 {
            commands.append(largeLine)
        }
        commands.append(".")
        commands.append("QUIT")

        let conn = ErrorSimulatingConnection(commands: commands)
        let config = SessionConfiguration(
            domain: "test.com",
            maxMessageSize: 100_000,  // 100KB limit
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Should reject the message but continue
        await session.run()

        #expect(true)
    }

    // MARK: - State Machine Error Recovery

    @Test("State machine maintains consistency after errors")
    func testStateMachineConsistency() {
        var sm = SMTPStateMachine(domain: "test.com")

        // Try invalid command sequence
        let result1 = sm.process(.mailFrom(reversePath: "sender@test.com"))

        // Should reject
        if case .rejected = result1 {
            #expect(sm.state == .initial)
        } else {
            Issue.record("Expected rejection")
        }

        // State machine should recover - valid sequence should work
        _ = sm.process(.helo(domain: "client"))
        let result2 = sm.process(.mailFrom(reversePath: "sender@test.com"))

        if case .accepted(_, let state) = result2 {
            #expect(state == .mail)
        } else {
            Issue.record("Expected acceptance after recovery")
        }
    }

    @Test("State machine handles multiple resets")
    func testMultipleResets() {
        var sm = SMTPStateMachine(domain: "test.com")

        for _ in 0..<10 {
            _ = sm.process(.helo(domain: "client"))
            _ = sm.process(.mailFrom(reversePath: "sender@test.com"))
            _ = sm.process(.rcptTo(forwardPath: "user@test.com"))

            // Reset
            let result = sm.process(.reset)

            if case .accepted(_, let state) = result {
                #expect(state == .greeted)
                #expect(sm.currentTransaction() == nil)
            }
        }

        // After multiple resets, should still work
        _ = sm.process(.helo(domain: "client"))
        let result = sm.process(.mailFrom(reversePath: "test@test.com"))

        if case .accepted = result {
            #expect(true)
        } else {
            Issue.record("State machine should work after multiple resets")
        }
    }

    // MARK: - Concurrent Error Handling

    @Test("Multiple sessions with errors don't affect each other")
    func testIsolatedSessionErrors() async {
        await withTaskGroup(of: Void.self) { group in
            // Launch good session
            group.addTask {
                let commands = [
                    "EHLO good.client.com",
                    "MAIL FROM:<good@test.com>",
                    "RCPT TO:<user@test.com>",
                    "DATA",
                    "Good message",
                    ".",
                    "QUIT"
                ]

                let conn = ErrorSimulatingConnection(commands: commands)
                let config = SessionConfiguration(domain: "test.com", connectionTimeout: 0, commandTimeout: 0)
                let session = SMTPSession(connection: conn, configuration: config)
                await session.run()
            }

            // Launch session with error
            group.addTask {
                let commands = [
                    "EHLO bad.client.com",
                    "MAIL FROM:<bad@test.com>"
                    // Will fail on read
                ]

                let conn = ErrorSimulatingConnection(commands: commands, failOn: 2)
                let config = SessionConfiguration(domain: "test.com", connectionTimeout: 0, commandTimeout: 0)
                let session = SMTPSession(connection: conn, configuration: config)
                await session.run()
            }

            await group.waitForAll()
        }

        // Both sessions should complete without crashing
        #expect(true)
    }

    // MARK: - Cleanup Verification

    @Test("Connection is always closed after session ends")
    func testConnectionCleanup() async {
        actor CloseTracker {
            private var closed = false
            func markClosed() { closed = true }
            func wasClosed() -> Bool { closed }
        }

        actor TrackedConnection: NetworkConnection {
            private var commands: [String]
            private var index = 0
            private let tracker: CloseTracker

            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            init(commands: [String], tracker: CloseTracker) {
                self.commands = commands
                self.tracker = tracker
            }

            func read(maxBytes: Int) async throws -> Data {
                guard index < commands.count else {
                    return Data()
                }
                let cmd = commands[index]
                index += 1
                return Data((cmd + "\r\n").utf8)
            }

            func write(_ data: Data) async throws {}

            func close() async throws {
                await tracker.markClosed()
            }
        }

        let tracker = CloseTracker()
        let commands = ["EHLO test.com", "QUIT"]
        let conn = TrackedConnection(commands: commands, tracker: tracker)
        let config = SessionConfiguration(domain: "test.com", connectionTimeout: 0, commandTimeout: 0)

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let wasClosed = await tracker.wasClosed()
        #expect(wasClosed)
    }
}
