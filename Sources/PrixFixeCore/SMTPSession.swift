/// SMTP Session Handler
///
/// Manages a single SMTP session: reads commands, processes them through
/// the state machine, and sends responses.

import Foundation
import PrixFixeNetwork
import PrixFixeMessage

/// SMTP session actor - handles one connection
public actor SMTPSession {
    /// The network connection
    private let connection: any NetworkConnection

    /// The state machine for this session
    private var stateMachine: SMTPStateMachine

    /// The command parser
    private let parser: SMTPCommandParser

    /// Configuration
    private let configuration: SessionConfiguration

    /// Message handler callback
    private let messageHandler: (@Sendable (EmailMessage) -> Void)?

    /// Whether the session is active
    private var isActive: Bool = true

    /// Connection start time
    private let connectionStart: Date

    /// Last command received time
    private var lastCommandTime: Date

    /// Initialize a new SMTP session
    /// - Parameters:
    ///   - connection: The network connection
    ///   - configuration: Session configuration
    ///   - messageHandler: Optional callback for received messages
    public init(
        connection: any NetworkConnection,
        configuration: SessionConfiguration,
        messageHandler: (@Sendable (EmailMessage) -> Void)? = nil
    ) {
        self.connection = connection
        self.configuration = configuration
        self.stateMachine = SMTPStateMachine(domain: configuration.domain)
        self.parser = SMTPCommandParser()
        self.messageHandler = messageHandler

        let now = Date()
        self.connectionStart = now
        self.lastCommandTime = now
    }

    /// Run the SMTP session
    public func run() async {
        do {
            // Send greeting
            try await sendResponse(.serviceReady(domain: configuration.domain))

            // Command loop
            while isActive {
                // Check connection timeout
                try checkConnectionTimeout()

                // Read a command line with command timeout
                guard let commandLine = try await readLineWithTimeout() else {
                    // Connection closed
                    break
                }

                // Update last command time
                lastCommandTime = Date()

                // Process the command
                try await processCommand(commandLine)

                // Check if we should close
                if stateMachine.state == .quit {
                    isActive = false
                    break
                }
            }
        } catch let error as SMTPError {
            // Handle SMTP-specific errors
            switch error {
            case .connectionTimeout:
                // Connection timed out - send timeout response if possible
                try? await sendResponse(.serviceNotAvailable("Connection timeout"))
            case .commandTimeout:
                // Command took too long - send timeout response
                try? await sendResponse(.serviceNotAvailable("Command timeout"))
            case .messageTooLarge:
                // Message size limit exceeded - error already sent
                break
            case .commandTooLong:
                // Command line too long - send error
                try? await sendResponse(.syntaxError("Command too long"))
            case .invalidEncoding:
                // Invalid UTF-8 encoding - send error
                try? await sendResponse(.syntaxError("Invalid character encoding"))
            case .connectionClosed:
                // Connection closed by client - no response needed
                break
            }
        } catch {
            // Handle unexpected errors gracefully
            // Try to send a generic error response
            try? await sendResponse(.localError("Internal server error"))
        }

        // Always clean up the connection
        try? await connection.close()
    }

    // MARK: - Command Processing

    /// Process a single command line
    private func processCommand(_ line: String) async throws {
        // Parse the command
        let command = parser.parse(line)

        // Process through state machine
        let result = stateMachine.process(command)

        switch result {
        case .accepted(let response, _):
            try await sendResponse(response)

            // If this was DATA, start reading message
            if case .data = command {
                try await readMessageData()
            }

        case .rejected(let response):
            try await sendResponse(response)

        case .continueData:
            // Should not happen at this level
            break

        case .close(let response):
            try await sendResponse(response)
            isActive = false
        }
    }

    /// Read and process message data (after DATA command)
    private func readMessageData() async throws {
        var messageLines: [String] = []
        var totalBytes = 0

        // Read until we see <CRLF>.<CRLF>
        while true {
            guard let line = try await readLine() else {
                throw SMTPError.connectionClosed
            }

            // Check for end-of-data marker: a line containing only "."
            if line == "." {
                break
            }

            // RFC 5321: Lines beginning with "." have it stripped (transparency)
            let processedLine = line.hasPrefix(".") ? String(line.dropFirst()) : line

            // Check message size limit
            let lineBytes = processedLine.utf8.count + 2  // +2 for CRLF
            totalBytes += lineBytes

            if totalBytes > configuration.maxMessageSize {
                // Send error response before throwing
                try await sendResponse(.messageTooLarge)
                throw SMTPError.messageTooLarge
            }

            messageLines.append(processedLine)
        }

        // Join lines with CRLF
        let messageContent = messageLines.joined(separator: "\r\n")
        let messageData = Data((messageContent + "\r\n").utf8)

        // Get transaction data before completing (as it will be cleared)
        guard let transaction = stateMachine.currentTransaction() else {
            try await sendResponse(.badSequence("No mail transaction"))
            return
        }

        // Complete the DATA transfer
        let result = stateMachine.completeData(messageData: messageData)

        switch result {
        case .accepted(let response, _):
            try await sendResponse(response)

            // Create and deliver the message to the handler
            if let handler = messageHandler {
                let from = EmailAddress(transaction.from)
                let recipients = transaction.recipients.map { EmailAddress($0) }
                let message = EmailMessage(from: from, recipients: recipients, data: messageData)
                handler(message)
            }

        case .rejected(let response):
            try await sendResponse(response)

        default:
            break
        }
    }

    // MARK: - I/O Operations

    /// Buffered read state
    private var readAheadBuffer = Data()

    /// Read a line from the connection (terminated by CRLF)
    private func readLine() async throws -> String? {
        // Read until we find CRLF in the buffer
        while true {
            // Search for CRLF in current buffer
            if let crlfRange = readAheadBuffer.range(of: Data([0x0D, 0x0A])) {
                // Found CRLF - extract the line
                let lineData = readAheadBuffer[..<crlfRange.lowerBound]

                // Keep the remaining data after CRLF
                if crlfRange.upperBound < readAheadBuffer.count {
                    readAheadBuffer = Data(readAheadBuffer[crlfRange.upperBound...])
                } else {
                    readAheadBuffer = Data()
                }

                // Convert to string
                guard let line = String(data: lineData, encoding: .utf8) else {
                    throw SMTPError.invalidEncoding
                }

                return line
            }

            // No CRLF yet - read more data
            let chunk = try await connection.read(maxBytes: 1024)

            guard !chunk.isEmpty else {
                // Connection closed
                if readAheadBuffer.isEmpty {
                    return nil
                } else {
                    // Partial line - treat as complete
                    guard let line = String(data: readAheadBuffer, encoding: .utf8) else {
                        throw SMTPError.invalidEncoding
                    }
                    readAheadBuffer = Data()
                    return line
                }
            }

            readAheadBuffer.append(chunk)

            // Prevent unbounded growth
            if readAheadBuffer.count > configuration.maxCommandLength {
                throw SMTPError.commandTooLong
            }
        }
    }

    /// Send a response to the client
    private func sendResponse(_ response: SMTPResponse) async throws {
        let data = response.data()
        try await connection.write(data)
    }

    // MARK: - Timeout Management

    /// Check if the connection has exceeded its total timeout
    private func checkConnectionTimeout() throws {
        guard configuration.connectionTimeout > 0 else { return }

        let elapsed = Date().timeIntervalSince(connectionStart)
        if elapsed > configuration.connectionTimeout {
            throw SMTPError.connectionTimeout
        }
    }

    /// Read a line with command timeout
    private func readLineWithTimeout() async throws -> String? {
        // If no timeout configured, just read normally
        guard configuration.commandTimeout > 0 else {
            return try await readLine()
        }

        // Use structured concurrency to race the read against the timeout
        return try await withThrowingTaskGroup(of: String?.self) { group in
            // Add read task
            group.addTask {
                try await self.readLine()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(self.configuration.commandTimeout))
                throw SMTPError.commandTimeout
            }

            // Wait for first result (either read completes or timeout fires)
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw SMTPError.connectionClosed
            }
            return result
        }
    }
}

// MARK: - Session Configuration

/// Configuration for an SMTP session
public struct SessionConfiguration: Sendable {
    /// The server domain name
    public let domain: String

    /// Maximum command line length
    public let maxCommandLength: Int

    /// Maximum message size in bytes
    public let maxMessageSize: Int

    /// Connection timeout in seconds (0 = no timeout)
    public let connectionTimeout: TimeInterval

    /// Command timeout in seconds (0 = no timeout)
    public let commandTimeout: TimeInterval

    /// Default configuration
    public static let `default` = SessionConfiguration(
        domain: "localhost",
        maxCommandLength: 512,
        maxMessageSize: 10 * 1024 * 1024,  // 10 MB
        connectionTimeout: 300,  // 5 minutes
        commandTimeout: 60  // 1 minute per command
    )

    /// Initialize session configuration
    public init(
        domain: String,
        maxCommandLength: Int = 512,
        maxMessageSize: Int = 10 * 1024 * 1024,
        connectionTimeout: TimeInterval = 300,
        commandTimeout: TimeInterval = 60
    ) {
        self.domain = domain
        self.maxCommandLength = maxCommandLength
        self.maxMessageSize = maxMessageSize
        self.connectionTimeout = connectionTimeout
        self.commandTimeout = commandTimeout
    }
}

// MARK: - SMTP Errors

/// Errors that can occur during SMTP session handling
public enum SMTPError: Error, CustomStringConvertible {
    /// The SMTP connection was closed unexpectedly
    case connectionClosed

    /// An SMTP command exceeded the maximum allowed length
    case commandTooLong

    /// Invalid character encoding was encountered in SMTP data
    case invalidEncoding

    /// The message exceeded the maximum size limit
    case messageTooLarge

    /// The SMTP connection timed out
    case connectionTimeout

    /// An SMTP command timed out
    case commandTimeout

    /// Human-readable description of the error
    public var description: String {
        switch self {
        case .connectionClosed:
            return "SMTP connection closed unexpectedly"
        case .commandTooLong:
            return "SMTP command exceeds maximum length"
        case .invalidEncoding:
            return "Invalid character encoding in SMTP data"
        case .messageTooLarge:
            return "Message exceeds maximum size limit"
        case .connectionTimeout:
            return "SMTP connection timed out"
        case .commandTimeout:
            return "SMTP command timed out"
        }
    }
}
