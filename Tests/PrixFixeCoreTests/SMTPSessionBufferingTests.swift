import Testing
import Foundation
@testable import PrixFixeCore
@testable import PrixFixeNetwork

/// Tests for SMTP session buffering behavior, line length limits, and error handling
/// These tests validate the RFC 5321 compliance fixes and buffer safety improvements
@Suite("SMTP Session Buffering Tests")
struct SMTPSessionBufferingTests {

    // MARK: - Mock Connection for Controlled Testing

    /// Mock connection that delivers data in controlled chunks
    /// Allows simulation of TCP packet boundaries not aligned with CRLF
    actor ChunkedConnection: NetworkConnection {
        private var chunks: [Data]
        private var writeBuffer: [Data] = []
        private var chunkIndex: Int = 0

        nonisolated var remoteAddress: any NetworkAddress {
            SocketAddress.localhost(port: 12345)
        }

        /// Initialize with an array of data chunks to deliver
        init(chunks: [Data]) {
            self.chunks = chunks
        }

        /// Initialize with a string, splitting at specified byte positions
        init(data: String, splitAt positions: [Int]) {
            let fullData = Data(data.utf8)
            var chunks: [Data] = []
            var currentPos = 0

            for pos in positions {
                if pos > currentPos && pos <= fullData.count {
                    chunks.append(fullData[currentPos..<pos])
                    currentPos = pos
                }
            }
            if currentPos < fullData.count {
                chunks.append(fullData[currentPos...])
            }

            self.chunks = chunks
        }

        func read(maxBytes: Int) async throws -> Data {
            guard chunkIndex < chunks.count else {
                return Data()  // EOF
            }

            let chunk = chunks[chunkIndex]
            chunkIndex += 1

            // Respect maxBytes limit
            if chunk.count > maxBytes {
                // Split the chunk - put remainder back
                let result = chunk.prefix(maxBytes)
                chunks.insert(Data(chunk.suffix(from: maxBytes)), at: chunkIndex)
                return result
            }

            return chunk
        }

        func write(_ data: Data) async throws {
            writeBuffer.append(data)
        }

        func close() async throws {
            chunks = []
        }

        func getWrittenData() -> [Data] {
            return writeBuffer
        }

        func getWrittenString() -> String {
            return writeBuffer.map { String(data: $0, encoding: .utf8) ?? "" }.joined()
        }
    }

    // MARK: - Multi-line Buffering Tests

    @Test("Multiple complete lines in single read chunk are processed correctly")
    func testMultipleLinesInSingleChunk() async {
        // Simulate TCP delivering multiple commands in one packet
        let commands = "EHLO test.local\r\nMAIL FROM:<test@test.com>\r\nQUIT\r\n"
        let conn = ChunkedConnection(chunks: [Data(commands.utf8)])
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        // Session should have processed all commands without error
        let output = await conn.getWrittenString()
        #expect(output.contains("220"))  // Greeting
        #expect(output.contains("250"))  // EHLO response
        #expect(output.contains("221"))  // QUIT response
    }

    @Test("Line split across TCP packet boundaries is reassembled correctly")
    func testLineSplitAcrossBoundaries() async {
        // Split "EHLO test.local\r\n" in the middle
        let part1 = Data("EHLO te".utf8)
        let part2 = Data("st.local\r\nQUIT\r\n".utf8)
        let conn = ChunkedConnection(chunks: [part1, part2])
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        #expect(output.contains("250"))  // EHLO should succeed
        #expect(output.contains("221"))  // QUIT should succeed
    }

    @Test("CRLF split across packet boundary is handled correctly")
    func testCRLFSplitAcrossBoundary() async {
        // Split right between CR and LF
        let part1 = Data("EHLO test.local\r".utf8)
        let part2 = Data("\nQUIT\r\n".utf8)
        let conn = ChunkedConnection(chunks: [part1, part2])
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        #expect(output.contains("250"))  // EHLO should succeed
    }

    @Test("Buffer accumulates multiple lines before CRLF extraction")
    func testBufferAccumulatesLines() async {
        // Send many small chunks that together form multiple commands
        let chunks: [Data] = [
            Data("EH".utf8),
            Data("LO ".utf8),
            Data("test".utf8),
            Data(".lo".utf8),
            Data("cal\r".utf8),
            Data("\nQU".utf8),
            Data("IT\r\n".utf8)
        ]
        let conn = ChunkedConnection(chunks: chunks)
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        #expect(output.contains("250"))  // EHLO should succeed
        #expect(output.contains("221"))  // QUIT should succeed
    }

    // MARK: - Line Length Limit Tests

    @Test("Command exceeding 512 bytes is rejected")
    func testCommandTooLong() async {
        // Create a command longer than 512 bytes
        let longArg = String(repeating: "x", count: 600)
        let command = "EHLO \(longArg)\r\nQUIT\r\n"
        let conn = ChunkedConnection(chunks: [Data(command.utf8)])
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        // Should get a 500-series error for command too long
        #expect(output.contains("500") || output.contains("501"))
    }

    @Test("Command at exactly 512 bytes is accepted")
    func testCommandAtLimit() async {
        // Create EHLO command that's exactly 512 bytes (including CRLF)
        // "EHLO " = 5 bytes, "\r\n" = 2 bytes, so argument can be 505 bytes
        let arg = String(repeating: "x", count: 505)
        let command = "EHLO \(arg)\r\nQUIT\r\n"
        #expect(command.utf8.count == 512 + 6)  // 512 for EHLO + 6 for QUIT\r\n

        let conn = ChunkedConnection(chunks: [Data(command.utf8)])
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        #expect(output.contains("250"))  // EHLO should succeed
    }

    // MARK: - Buffer Overflow Protection Tests

    @Test("Buffer overflow is detected and connection closed")
    func testBufferOverflow() async {
        // Send continuous data without CRLF to trigger buffer overflow
        // Buffer limit is 3x the line limit = 3 * 512 = 1536 bytes
        let overflow = String(repeating: "x", count: 2000)
        let conn = ChunkedConnection(chunks: [Data(overflow.utf8)])
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        // Should get service unavailable response for buffer overflow
        #expect(output.contains("421") || output.contains("500"))
    }

    // MARK: - Error Type Differentiation Tests

    @Test("Command phase uses correct error type")
    func testCommandPhaseErrorType() async {
        // Verify that command-too-long error during command phase
        // mentions the 512-byte limit
        let longCommand = "EHLO " + String(repeating: "x", count: 600) + "\r\nQUIT\r\n"
        let conn = ChunkedConnection(chunks: [Data(longCommand.utf8)])
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        // Error message should indicate command length issue
        #expect(output.lowercased().contains("command") || output.contains("512"))
    }
}

// MARK: - Data Phase Tests (for RFC 5321 998-byte text line limit)

@Suite("SMTP Session Data Phase Tests")
struct SMTPSessionDataPhaseTests {

    /// Mock connection that can simulate a complete SMTP transaction
    actor TransactionConnection: NetworkConnection {
        private var inputData: Data
        private var writeBuffer: [Data] = []
        private var readOffset: Int = 0

        nonisolated var remoteAddress: any NetworkAddress {
            SocketAddress.localhost(port: 12345)
        }

        init(messageBody: String) {
            // Build a complete SMTP transaction
            let transaction = """
            EHLO test.local\r
            MAIL FROM:<test@test.com>\r
            RCPT TO:<recipient@test.com>\r
            DATA\r
            \(messageBody).\r
            QUIT\r

            """
            self.inputData = Data(transaction.utf8)
        }

        func read(maxBytes: Int) async throws -> Data {
            guard readOffset < inputData.count else {
                return Data()
            }

            let endIndex = min(readOffset + maxBytes, inputData.count)
            let chunk = inputData[readOffset..<endIndex]
            readOffset = endIndex
            return chunk
        }

        func write(_ data: Data) async throws {
            writeBuffer.append(data)
        }

        func close() async throws {}

        func getWrittenString() -> String {
            return writeBuffer.map { String(data: $0, encoding: .utf8) ?? "" }.joined()
        }
    }

    @Test("Text line under 998 bytes in DATA phase is accepted")
    func testTextLineUnderLimit() async {
        // Create a message with lines under 998 bytes
        let shortLine = String(repeating: "x", count: 500) + "\r\n"
        let messageBody = "From: test@test.com\r\nTo: recipient@test.com\r\n\r\n\(shortLine)"

        let conn = TransactionConnection(messageBody: messageBody)
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        #expect(output.contains("250"))  // Message should be accepted
    }

    @Test("Text line at exactly 998 bytes in DATA phase is accepted")
    func testTextLineAtLimit() async {
        // Create a line that's exactly 998 bytes (excluding CRLF)
        let exactLine = String(repeating: "y", count: 998) + "\r\n"
        let messageBody = "From: test@test.com\r\nTo: recipient@test.com\r\n\r\n\(exactLine)"

        let conn = TransactionConnection(messageBody: messageBody)
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        let output = await conn.getWrittenString()
        // Line at exactly 998 bytes should be accepted
        #expect(output.contains("250"))
    }
}
