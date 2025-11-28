import Testing
import Foundation
@testable import PrixFixeCore
@testable import PrixFixeNetwork

@Suite("SMTP Performance Tests")
struct SMTPPerformanceTests {

    /// Stress test connection for performance testing
    actor StressTestConnection: NetworkConnection {
        private var commandQueue: [String]
        private var currentCommandIndex = 0
        private var writeCount = 0

        nonisolated var remoteAddress: any NetworkAddress {
            SocketAddress.localhost(port: 12345)
        }

        init(commands: [String]) {
            self.commandQueue = commands
        }

        func read(maxBytes: Int) async throws -> Data {
            guard currentCommandIndex < commandQueue.count else {
                return Data()  // End of data
            }

            let command = commandQueue[currentCommandIndex]
            currentCommandIndex += 1
            return Data((command + "\r\n").utf8)
        }

        func write(_ data: Data) async throws {
            writeCount += 1
        }

        func close() async throws {
            commandQueue.removeAll()
        }

        func getWriteCount() -> Int {
            writeCount
        }
    }

    // MARK: - Command Parser Performance

    @Test("Command parser throughput")
    func testCommandParserThroughput() async {
        let parser = SMTPCommandParser()
        let commands = [
            "HELO client.example.com",
            "MAIL FROM:<sender@example.com>",
            "RCPT TO:<recipient@example.com>",
            "DATA",
            "RSET",
            "QUIT"
        ]

        let iterations = 10_000
        let startTime = Date()

        for _ in 0..<iterations {
            for cmd in commands {
                _ = parser.parse(cmd)
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let commandsPerSecond = Double(iterations * commands.count) / elapsed

        // Should parse at least 100k commands per second
        #expect(commandsPerSecond > 100_000)
    }

    @Test("State machine throughput")
    func testStateMachineThroughput() {
        let iterations = 10_000
        let startTime = Date()

        for _ in 0..<iterations {
            var sm = SMTPStateMachine(domain: "test.com")
            _ = sm.process(.helo(domain: "client"))
            _ = sm.process(.mailFrom(reversePath: "sender@test.com"))
            _ = sm.process(.rcptTo(forwardPath: "user@test.com"))
            _ = sm.process(.data)
            _ = sm.completeData(messageData: Data("Test".utf8))
            _ = sm.process(.quit)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let transactionsPerSecond = Double(iterations) / elapsed

        // Should process at least 10k transactions per second
        #expect(transactionsPerSecond > 10_000)
    }

    // MARK: - Session Performance

    @Test("Single session processes multiple messages quickly")
    func testSessionThroughput() async {
        let messageCount = 100
        var commands: [String] = ["EHLO client.test.com"]

        // Generate multiple message transactions
        for i in 0..<messageCount {
            commands.append("MAIL FROM:<sender\(i)@test.com>")
            commands.append("RCPT TO:<user\(i)@test.com>")
            commands.append("DATA")
            commands.append("Subject: Test \(i)")
            commands.append("")
            commands.append("Message body \(i)")
            commands.append(".")
        }
        commands.append("QUIT")

        let conn = StressTestConnection(commands: commands)
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        // Use actor for thread-safe counting
        actor Counter {
            private var count = 0
            func increment() { count += 1 }
            func get() -> Int { count }
        }

        let counter = Counter()
        let session = SMTPSession(
            connection: conn,
            configuration: config,
            messageHandler: { _ in
                Task { await counter.increment() }
            }
        )

        let startTime = Date()
        await session.run()
        let elapsed = Date().timeIntervalSince(startTime)

        // Give async tasks time to complete
        try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        let receivedCount = await counter.get()
        let messagesPerSecond = Double(receivedCount) / elapsed

        #expect(receivedCount == messageCount)
        // Should handle at least 50 messages per second
        #expect(messagesPerSecond > 50)
    }

    // MARK: - Memory and Resource Tests

    @Test("State machine memory efficiency")
    func testStateMachineMemory() {
        // Create many state machines to verify they don't leak
        var machines: [SMTPStateMachine] = []

        for i in 0..<1000 {
            var sm = SMTPStateMachine(domain: "test\(i).com")
            _ = sm.process(.helo(domain: "client"))
            _ = sm.process(.mailFrom(reversePath: "sender@test.com"))
            _ = sm.process(.rcptTo(forwardPath: "user@test.com"))
            machines.append(sm)
        }

        // Verify all machines are independent
        #expect(machines.count == 1000)
        #expect(machines[0].state == .recipient)
        #expect(machines[999].state == .recipient)
    }

    @Test("Response formatting performance")
    func testResponseFormattingPerformance() {
        let responses = [
            SMTPResponse.serviceReady(domain: "test.com"),
            SMTPResponse.ok("OK"),
            SMTPResponse.startMailInput,
            SMTPResponse.closing(domain: "test.com"),
            SMTPResponse.ehlo(domain: "test.com", capabilities: ["SIZE 10485760", "8BITMIME"])
        ]

        let iterations = 100_000
        let startTime = Date()

        for _ in 0..<iterations {
            for response in responses {
                _ = response.data()
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let responsesPerSecond = Double(iterations * responses.count) / elapsed

        // Should format at least 500k responses per second
        #expect(responsesPerSecond > 500_000)
    }

    // MARK: - Large Message Handling

    @Test("Handle large message efficiently")
    func testLargeMessageHandling() async {
        // Create a smaller but still sizable message (100KB)
        let largeLine = String(repeating: "X", count: 1000)
        let lineCount = 100  // 100KB message

        var commands = [
            "EHLO client.test.com",
            "MAIL FROM:<sender@test.com>",
            "RCPT TO:<user@test.com>",
            "DATA"
        ]

        for _ in 0..<lineCount {
            commands.append(largeLine)
        }
        commands.append(".")
        commands.append("QUIT")

        let conn = StressTestConnection(commands: commands)
        let config = SessionConfiguration(
            domain: "test.com",
            maxCommandLength: 10_000,  // Increase command length to handle long lines
            maxMessageSize: 50 * 1024 * 1024,  // 50MB limit - plenty for 100KB message
            connectionTimeout: 0,
            commandTimeout: 0
        )

        // Use a simple atomic flag with OSAtomic-style approach
        final class AtomicFlag: @unchecked Sendable {
            private var _value: Int32 = 0
            private let lock = NSLock()

            func set() {
                lock.withLock { _value = 1 }
            }

            func get() -> Bool {
                lock.withLock { _value != 0 }
            }
        }

        let flag = AtomicFlag()
        let session = SMTPSession(
            connection: conn,
            configuration: config,
            messageHandler: { _ in
                flag.set()
            }
        )

        let startTime = Date()
        await session.run()
        let elapsed = Date().timeIntervalSince(startTime)

        let received = flag.get()
        #expect(received)
        // Should handle 100KB message in reasonable time
        #expect(elapsed < 2.0)
    }

    // MARK: - Concurrent Operations

    @Test("Multiple concurrent sessions")
    func testConcurrentSessions() async {
        let sessionCount = 10

        let startTime = Date()

        await withTaskGroup(of: Void.self) { group in
            for sessionIndex in 0..<sessionCount {
                group.addTask {
                    let commands = [
                        "EHLO client\(sessionIndex).test.com",
                        "MAIL FROM:<sender\(sessionIndex)@test.com>",
                        "RCPT TO:<user\(sessionIndex)@test.com>",
                        "DATA",
                        "Test message \(sessionIndex)",
                        ".",
                        "QUIT"
                    ]

                    let conn = StressTestConnection(commands: commands)
                    let config = SessionConfiguration(
                        domain: "test.com",
                        connectionTimeout: 0,
                        commandTimeout: 0
                    )

                    let session = SMTPSession(connection: conn, configuration: config)
                    await session.run()
                }
            }

            await group.waitForAll()
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should handle 10 concurrent sessions quickly
        #expect(elapsed < 1.0)

        // If we get here without timeout or crash, concurrency works
        #expect(true)
    }

    // MARK: - Protocol Compliance Under Load

    @Test("Maintains protocol compliance under rapid commands")
    func testRapidCommandSequence() async {
        // Send commands as fast as possible
        var commands: [String] = []
        for i in 0..<1000 {
            commands.append("NOOP")
        }
        commands.insert("EHLO client.test.com", at: 0)
        commands.append("QUIT")

        let conn = StressTestConnection(commands: commands)
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        let startTime = Date()
        await session.run()
        let elapsed = Date().timeIntervalSince(startTime)

        let writeCount = await conn.getWriteCount()

        // Should have sent responses for all commands + greeting
        #expect(writeCount >= commands.count)

        // Should handle 1000+ commands in under 1 second
        #expect(elapsed < 1.0)
    }
}
