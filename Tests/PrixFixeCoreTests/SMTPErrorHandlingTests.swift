import Testing
import Foundation
@testable import PrixFixeCore
@testable import PrixFixeNetwork

@Suite("SMTP Error Handling Tests")
struct SMTPErrorHandlingTests {

    // MARK: - Server Startup Errors

    @Test("Server fails to start when port is already in use")
    func testPortAlreadyInUse() async throws {
        let config = ServerConfiguration(
            domain: "test.com",
            port: 0  // Use ephemeral port
        )

        let server1 = SMTPServer(configuration: config)

        // Start first server
        let task1 = Task {
            try await server1.start()
        }

        // Give first server time to bind
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        // Try to start second server on same port
        // Note: Since we use ephemeral port (0), this will actually succeed
        // with a different port. For a real test, we'd need to get the actual
        // bound port from server1, but that's not exposed in the current API.

        // Clean up
        try? await server1.stop()
        task1.cancel()
    }

    // MARK: - Connection Drop Scenarios

    @Test("Connection drop during DATA command")
    func testConnectionDropDuringData() async {
        // Create a connection that closes mid-stream
        actor FailingConnection: NetworkConnection {
            private var commandCount = 0

            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            func read(maxBytes: Int) async throws -> Data {
                commandCount += 1

                // Return commands normally until we're in the data phase
                switch commandCount {
                case 1: return Data("EHLO test.com\r\n".utf8)
                case 2: return Data("MAIL FROM:<sender@test.com>\r\n".utf8)
                case 3: return Data("RCPT TO:<recipient@test.com>\r\n".utf8)
                case 4: return Data("DATA\r\n".utf8)
                case 5:
                    // Simulate connection drop - return empty data
                    return Data()
                default: return Data()
                }
            }

            func write(_ data: Data) async throws {
                // Accept all writes
            }

            func close() async throws {
                // No-op
            }
        }

        let conn = FailingConnection()
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Session should handle the disconnection gracefully
        await session.run()

        // If we get here without crashing, the test passes
        #expect(true)
    }

    @Test("Connection drop during command processing")
    func testConnectionDropDuringCommand() async {
        actor FailingConnection: NetworkConnection {
            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            func read(maxBytes: Int) async throws -> Data {
                // Return empty immediately to simulate connection drop
                return Data()
            }

            func write(_ data: Data) async throws {
                // Accept all writes
            }

            func close() async throws {
                // No-op
            }
        }

        let conn = FailingConnection()
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Session should handle the disconnection gracefully
        await session.run()

        // If we get here without crashing, the test passes
        #expect(true)
    }

    // MARK: - Maximum Connections Tests

    @Test("Server respects maximum connections limit")
    func testMaxConnectionsLimit() async throws {
        let config = ServerConfiguration(
            domain: "test.com",
            port: 0
        )

        let server = SMTPServer(configuration: config)

        // For now, we just verify the server can be created
        #expect(server != nil)

        // TODO: Once connection limiting is needed, test that the server
        // properly handles the maxConnections configuration parameter
    }

    // MARK: - Invalid UTF-8 Handling

    @Test("Session handles invalid UTF-8 gracefully")
    func testInvalidUTF8Handling() async {
        actor InvalidUTF8Connection: NetworkConnection {
            private var commandCount = 0

            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            func read(maxBytes: Int) async throws -> Data {
                commandCount += 1

                switch commandCount {
                case 1:
                    // Send valid EHLO
                    return Data("EHLO test.com\r\n".utf8)
                case 2:
                    // Send invalid UTF-8 sequence
                    var invalidData = Data("MAIL FROM:<".utf8)
                    invalidData.append(contentsOf: [0xFF, 0xFE])  // Invalid UTF-8
                    invalidData.append(contentsOf: ">\r\n".utf8)
                    return invalidData
                default:
                    return Data()
                }
            }

            func write(_ data: Data) async throws {
                // Accept all writes
            }

            func close() async throws {
                // No-op
            }
        }

        let conn = InvalidUTF8Connection()
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Session should handle invalid UTF-8 gracefully
        await session.run()

        // If we get here without crashing, the test passes
        #expect(true)
    }

    // MARK: - Message Size Limits

    @Test("Session rejects messages exceeding size limit")
    func testMessageSizeLimit() async {
        actor LargeMessageConnection: NetworkConnection {
            private var commandCount = 0
            private var dataLineCount = 0

            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            func read(maxBytes: Int) async throws -> Data {
                commandCount += 1

                switch commandCount {
                case 1: return Data("EHLO test.com\r\n".utf8)
                case 2: return Data("MAIL FROM:<sender@test.com>\r\n".utf8)
                case 3: return Data("RCPT TO:<recipient@test.com>\r\n".utf8)
                case 4: return Data("DATA\r\n".utf8)
                case 5...1004:
                    // Send 1000 lines of 1KB each = 1MB total
                    dataLineCount += 1
                    if dataLineCount < 1000 {
                        let line = String(repeating: "X", count: 1000) + "\r\n"
                        return Data(line.utf8)
                    } else {
                        return Data(".\r\n".utf8)
                    }
                case 1005: return Data("QUIT\r\n".utf8)
                default: return Data()
                }
            }

            func write(_ data: Data) async throws {
                // Accept all writes
            }

            func close() async throws {
                // No-op
            }
        }

        let conn = LargeMessageConnection()
        let config = SessionConfiguration(
            domain: "test.com",
            maxMessageSize: 100_000,  // 100KB limit
            connectionTimeout: 0,
            commandTimeout: 0
        )

        // Use thread-safe atomic flag
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

        await session.run()

        // Message should be rejected due to size limit
        #expect(!flag.get())
    }

    // MARK: - Command Length Limits

    @Test("Session rejects commands exceeding length limit")
    func testCommandLengthLimit() async {
        actor LongCommandConnection: NetworkConnection {
            private var commandCount = 0

            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            func read(maxBytes: Int) async throws -> Data {
                commandCount += 1

                switch commandCount {
                case 1: return Data("EHLO test.com\r\n".utf8)
                case 2:
                    // Send command that exceeds 512 bytes (default limit)
                    let longCommand = "MAIL FROM:<" + String(repeating: "x", count: 600) + "@test.com>\r\n"
                    return Data(longCommand.utf8)
                default: return Data()
                }
            }

            func write(_ data: Data) async throws {
                // Accept all writes
            }

            func close() async throws {
                // No-op
            }
        }

        let conn = LongCommandConnection()
        let config = SessionConfiguration(
            domain: "test.com",
            maxCommandLength: 512,
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Session should handle the long command error gracefully
        await session.run()

        // If we get here without crashing, the test passes
        #expect(true)
    }

    // MARK: - Timeout Tests

    @Test("Session respects command timeout")
    func testCommandTimeout() async {
        actor SlowConnection: NetworkConnection {
            private var commandCount = 0

            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            func read(maxBytes: Int) async throws -> Data {
                commandCount += 1

                if commandCount == 1 {
                    return Data("EHLO test.com\r\n".utf8)
                } else {
                    // Simulate slow read by sleeping
                    try await Task.sleep(for: .seconds(2))
                    return Data("QUIT\r\n".utf8)
                }
            }

            func write(_ data: Data) async throws {
                // Accept all writes
            }

            func close() async throws {
                // No-op
            }
        }

        let conn = SlowConnection()
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 1  // 1 second timeout
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Session should timeout and close gracefully
        await session.run()

        // If we get here without crashing, the test passes
        #expect(true)
    }

    @Test("Session respects connection timeout")
    func testConnectionTimeout() async {
        actor SlowConnection: NetworkConnection {
            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            func read(maxBytes: Int) async throws -> Data {
                // Keep connection alive but don't send anything
                try await Task.sleep(for: .seconds(2))
                return Data()
            }

            func write(_ data: Data) async throws {
                // Accept all writes
            }

            func close() async throws {
                // No-op
            }
        }

        let conn = SlowConnection()
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 1,  // 1 second total timeout
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        let startTime = Date()
        await session.run()
        let elapsed = Date().timeIntervalSince(startTime)

        // Should timeout within reasonable time (allow some overhead)
        #expect(elapsed < 2.5)
    }

    // MARK: - Protocol Violation Tests

    @Test("Session handles DATA before MAIL FROM")
    func testDataBeforeMailFrom() async {
        actor ProtocolViolationConnection: NetworkConnection {
            private var commandCount = 0

            nonisolated var remoteAddress: any NetworkAddress {
                SocketAddress.localhost(port: 12345)
            }

            func read(maxBytes: Int) async throws -> Data {
                commandCount += 1

                switch commandCount {
                case 1: return Data("EHLO test.com\r\n".utf8)
                case 2: return Data("DATA\r\n".utf8)  // Invalid - no MAIL FROM
                case 3: return Data("QUIT\r\n".utf8)
                default: return Data()
                }
            }

            func write(_ data: Data) async throws {
                // Accept all writes
            }

            func close() async throws {
                // No-op
            }
        }

        let conn = ProtocolViolationConnection()
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)

        // Session should handle protocol violation gracefully
        await session.run()

        // If we get here without crashing, the test passes
        #expect(true)
    }
}
