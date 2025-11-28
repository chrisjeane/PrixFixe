/// PrixFixeCore - SMTP Protocol Implementation
///
/// Core SMTP protocol handling including state machine, command parsing,
/// and session management.

import Foundation
import PrixFixeNetwork
import PrixFixeMessage

/// The main SMTP server actor that orchestrates connection handling
///
/// `SMTPServer` manages the lifecycle of SMTP connections and coordinates
/// between the network layer and protocol implementation.
///
/// ## Example
///
/// ```swift
/// let server = SMTPServer(configuration: .default)
/// server.messageHandler = { message in
///     print("Received: \(message)")
/// }
/// try await server.start()
/// ```
public actor SMTPServer {
    /// Configuration for the SMTP server
    private let configuration: ServerConfiguration

    /// Network transport
    private var transport: (any NetworkTransport)?

    /// Active session tasks
    private var sessionTasks: [UUID: Task<Void, Never>] = [:]

    /// Handler for received messages
    public var messageHandler: (@Sendable (EmailMessage) -> Void)?

    /// Whether the server is running
    private var isRunning: Bool = false

    /// Initialize a new SMTP server
    /// - Parameter configuration: Server configuration
    public init(configuration: ServerConfiguration = .default) {
        self.configuration = configuration
    }

    /// Start the SMTP server
    public func start() async throws {
        guard !isRunning else {
            throw ServerError.alreadyRunning
        }

        // Create and bind transport
        let socket = FoundationSocket()
        let address = SocketAddress.anyAddress(port: configuration.port)

        try await socket.bind(to: address)
        try await socket.listen(backlog: configuration.maxConnections)

        self.transport = socket
        self.isRunning = true

        // Accept connections
        await acceptLoop()
    }

    /// Stop the SMTP server gracefully
    public func stop() async throws {
        guard isRunning else { return }

        isRunning = false

        // Cancel all active sessions
        for (_, task) in sessionTasks {
            task.cancel()
        }
        sessionTasks.removeAll()

        // Close transport
        try await transport?.close()
        transport = nil
    }

    // MARK: - Connection Handling

    /// Accept incoming connections
    private func acceptLoop() async {
        while isRunning {
            do {
                guard let transport = self.transport else { break }

                // Accept a connection
                let connection = try await transport.accept()

                // Create session configuration
                let sessionConfig = SessionConfiguration(
                    domain: configuration.domain,
                    maxCommandLength: 512,
                    maxMessageSize: configuration.maxMessageSize,
                    connectionTimeout: 300,  // 5 minutes
                    commandTimeout: 60  // 1 minute
                )

                // Spawn a session handler
                let sessionID = UUID()
                let task = Task { [weak self] in
                    await self?.handleSession(connection: connection, configuration: sessionConfig)
                    await self?.removeSession(id: sessionID)
                }

                sessionTasks[sessionID] = task

            } catch {
                // Log error in production (use proper logging framework)
                // For now, continue operation unless server stopped
                if !isRunning {
                    break  // Server stopped gracefully
                }
                // Continue accepting connections despite error
                // This prevents one connection error from crashing the entire server
            }
        }
    }

    /// Handle a single SMTP session
    private func handleSession(connection: any NetworkConnection, configuration: SessionConfiguration) async {
        // Capture messageHandler to avoid data race
        let handler = messageHandler

        let session = SMTPSession(
            connection: connection,
            configuration: configuration,
            messageHandler: handler
        )

        await session.run()
    }

    /// Remove a completed session
    private func removeSession(id: UUID) {
        sessionTasks.removeValue(forKey: id)
    }
}

// MARK: - Server Configuration

/// Configuration for the SMTP server
public struct ServerConfiguration: Sendable {
    /// The server domain name
    public let domain: String

    /// The port to bind to
    public let port: UInt16

    /// Maximum number of concurrent connections
    public let maxConnections: Int

    /// Maximum message size in bytes
    public let maxMessageSize: Int

    /// Default configuration
    public static let `default` = ServerConfiguration(
        domain: "localhost",
        port: 2525,
        maxConnections: 100,
        maxMessageSize: 10 * 1024 * 1024 // 10 MB
    )

    /// Initialize server configuration
    public init(
        domain: String = "localhost",
        port: UInt16,
        maxConnections: Int = 100,
        maxMessageSize: Int = 10 * 1024 * 1024
    ) {
        self.domain = domain
        self.port = port
        self.maxConnections = maxConnections
        self.maxMessageSize = maxMessageSize
    }
}

// MARK: - Server Errors

/// Errors that can occur during SMTP server lifecycle operations
public enum ServerError: Error, CustomStringConvertible {
    /// The server is already running and cannot be started again
    case alreadyRunning

    /// The server is not running and cannot be stopped
    case notRunning

    /// Human-readable description of the error
    public var description: String {
        switch self {
        case .alreadyRunning:
            return "SMTP server is already running"
        case .notRunning:
            return "SMTP server is not running"
        }
    }
}
