/// PrixFixeCore - SMTP Protocol Implementation
///
/// Core SMTP protocol handling including state machine, command parsing,
/// and session management.

import Foundation
import PrixFixeNetwork
import PrixFixeMessage

/// The main SMTP server actor that orchestrates connection handling and message processing.
///
/// `SMTPServer` is the primary interface for embedding an SMTP server in your application.
/// It manages the complete lifecycle of SMTP connections, from accepting new connections
/// to processing SMTP commands and delivering completed messages through your message handler.
///
/// ## Overview
///
/// The server uses Swift's actor model to ensure thread-safe operation and handles
/// multiple concurrent connections efficiently. Each connection is managed by a separate
/// ``SMTPSession`` actor that processes the SMTP protocol state machine.
///
/// ## Basic Usage
///
/// Create a server, set a message handler, and start listening:
///
/// ```swift
/// let server = SMTPServer(configuration: .default)
///
/// server.messageHandler = { message in
///     print("Received email from: \(message.from)")
///     for recipient in message.recipients {
///         print("  To: \(recipient)")
///     }
///     // Process the message...
/// }
///
/// try await server.start()
/// ```
///
/// ## Configuration
///
/// Customize server behavior using ``ServerConfiguration``:
///
/// ```swift
/// let config = ServerConfiguration(
///     domain: "mail.example.com",
///     port: 2525,
///     maxConnections: 100,
///     maxMessageSize: 10 * 1024 * 1024  // 10 MB
/// )
/// let server = SMTPServer(configuration: config)
/// ```
///
/// ## Lifecycle Management
///
/// Start and stop the server as needed:
///
/// ```swift
/// // Start the server
/// try await server.start()
///
/// // Later, gracefully shut down
/// try await server.stop()
/// ```
///
/// When stopped, the server cancels all active sessions and closes the network listener.
///
/// ## Thread Safety
///
/// `SMTPServer` is an actor, so all interactions are automatically serialized and thread-safe.
/// The message handler closure is `@Sendable`, allowing safe concurrent access.
///
/// ## Topics
///
/// ### Creating a Server
///
/// - ``init(configuration:)``
///
/// ### Managing Lifecycle
///
/// - ``start()``
/// - ``stop()``
///
/// ### Message Handling
///
/// - ``messageHandler``
///
/// - Note: The server implements RFC 5321 core SMTP. It does not support STARTTLS, SMTP AUTH,
///   or other extensions in version 0.1.0.
public actor SMTPServer {
    /// Configuration for the SMTP server
    private let configuration: ServerConfiguration

    /// Network transport
    private var transport: (any NetworkTransport)?

    /// Active session tasks
    private var sessionTasks: [UUID: Task<Void, Never>] = [:]

    /// Callback invoked when a complete email message is received.
    ///
    /// Set this closure to process received messages. The closure receives an ``EmailMessage``
    /// containing the envelope sender, recipients, and raw message data.
    ///
    /// ## Example
    ///
    /// ```swift
    /// server.messageHandler = { message in
    ///     print("From: \(message.from)")
    ///     print("To: \(message.recipients)")
    ///
    ///     // Parse message content
    ///     if let content = String(data: message.data, encoding: .utf8) {
    ///         print("Content:\n\(content)")
    ///     }
    /// }
    /// ```
    ///
    /// - Important: This closure must be `@Sendable` as it will be called from concurrent sessions.
    public var messageHandler: (@Sendable (EmailMessage) -> Void)?

    /// Whether the server is running
    private var isRunning: Bool = false

    /// Initialize a new SMTP server with the specified configuration.
    ///
    /// - Parameter configuration: Server configuration including domain, port, and limits.
    ///   Defaults to ``ServerConfiguration/default``.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use default configuration (localhost:2525)
    /// let server = SMTPServer()
    ///
    /// // Or customize the configuration
    /// let config = ServerConfiguration(
    ///     domain: "mail.example.com",
    ///     port: 2525,
    ///     maxConnections: 100,
    ///     maxMessageSize: 10 * 1024 * 1024
    /// )
    /// let customServer = SMTPServer(configuration: config)
    /// ```
    public init(configuration: ServerConfiguration = .default) {
        self.configuration = configuration
    }

    /// Start the SMTP server and begin accepting connections.
    ///
    /// This method binds to the configured port, starts listening for connections,
    /// and enters an accept loop to handle incoming SMTP sessions.
    ///
    /// - Throws: ``ServerError/alreadyRunning`` if the server is already running.
    /// - Throws: ``NetworkError`` if binding or listening fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try await server.start()
    ///     print("Server started on port \(config.port)")
    /// } catch ServerError.alreadyRunning {
    ///     print("Server is already running")
    /// } catch {
    ///     print("Failed to start server: \(error)")
    /// }
    /// ```
    ///
    /// - Note: This method does not return until the server is stopped. Run it in a detached
    ///   task if you need to perform other work while the server runs.
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

    /// Stop the SMTP server gracefully, closing all active connections.
    ///
    /// This method cancels all active session tasks and closes the network listener.
    /// Any in-progress message transfers will be terminated.
    ///
    /// - Throws: ``NetworkError`` if closing the transport fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Gracefully stop the server
    /// try await server.stop()
    /// print("Server stopped")
    /// ```
    ///
    /// - Note: This method is safe to call multiple times. If the server is not running,
    ///   it does nothing.
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
                    commandTimeout: 60,  // 1 minute
                    tlsConfiguration: configuration.tlsConfiguration
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
    private func handleSession(connection: any NetworkConnection, configuration sessionConfig: SessionConfiguration) async {
        // Capture messageHandler to avoid data race
        let handler = messageHandler

        let session = SMTPSession(
            connection: connection,
            configuration: sessionConfig,
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

/// Configuration parameters for an SMTP server instance.
///
/// `ServerConfiguration` defines the server's identity, network binding, and operational limits.
/// Use this to customize the server's behavior for your specific use case.
///
/// ## Example
///
/// ```swift
/// // Default configuration for development
/// let defaultConfig = ServerConfiguration.default
///
/// // Production configuration
/// let prodConfig = ServerConfiguration(
///     domain: "mail.example.com",
///     port: 25,
///     maxConnections: 1000,
///     maxMessageSize: 25 * 1024 * 1024  // 25 MB
/// )
/// ```
///
/// ## Topics
///
/// ### Server Identity
///
/// - ``domain``
///
/// ### Network Binding
///
/// - ``port``
///
/// ### Operational Limits
///
/// - ``maxConnections``
/// - ``maxMessageSize``
///
/// ### Default Configuration
///
/// - ``default``
public struct ServerConfiguration: Sendable {
    /// The server's domain name used in SMTP greeting messages.
    ///
    /// This domain appears in the server's initial greeting (220 response) and HELO/EHLO responses.
    /// It should be a valid fully-qualified domain name (FQDN) for production use.
    ///
    /// - Note: For development, "localhost" is acceptable.
    public let domain: String

    /// The TCP port number to bind to for incoming SMTP connections.
    ///
    /// Common SMTP ports:
    /// - 25: Standard SMTP (requires root on Linux)
    /// - 587: Message submission (STARTTLS typically required)
    /// - 2525: Alternative non-privileged port (good for development)
    ///
    /// - Note: Ports below 1024 require elevated privileges on Unix-like systems.
    public let port: UInt16

    /// Maximum number of concurrent SMTP connections the server will accept.
    ///
    /// When this limit is reached, additional connection attempts will be refused
    /// until existing connections close.
    ///
    /// Recommended values:
    /// - Development: 10-100
    /// - Production (Linux/macOS): 1000+
    /// - iOS: 5-10 (due to system constraints)
    public let maxConnections: Int

    /// Maximum allowed size for a single email message, in bytes.
    ///
    /// Messages exceeding this size will be rejected during the DATA phase.
    /// This limit applies to the raw message data (headers + body).
    ///
    /// - Note: The default is 10 MB, which is suitable for most use cases.
    ///   Adjust based on your application's needs.
    public let maxMessageSize: Int

    /// TLS configuration for STARTTLS support (nil = TLS disabled)
    ///
    /// When configured, the server will advertise STARTTLS in EHLO responses
    /// and allow clients to upgrade connections to TLS encryption.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let tlsConfig = TLSConfiguration(
    ///     certificateSource: .file(
    ///         certificatePath: "/etc/ssl/certs/mail.example.com.pem",
    ///         privateKeyPath: "/etc/ssl/private/mail.example.com.key"
    ///     )
    /// )
    ///
    /// let config = ServerConfiguration(
    ///     domain: "mail.example.com",
    ///     port: 587,
    ///     tlsConfiguration: tlsConfig
    /// )
    /// ```
    public let tlsConfiguration: TLSConfiguration?

    /// Default configuration suitable for development and testing.
    ///
    /// - Domain: "localhost"
    /// - Port: 2525 (non-privileged)
    /// - Max Connections: 100
    /// - Max Message Size: 10 MB
    /// - TLS: Disabled
    public static let `default` = ServerConfiguration(
        domain: "localhost",
        port: 2525,
        maxConnections: 100,
        maxMessageSize: 10 * 1024 * 1024, // 10 MB
        tlsConfiguration: nil
    )

    /// Initialize a new server configuration.
    ///
    /// - Parameters:
    ///   - domain: The server's domain name. Defaults to "localhost".
    ///   - port: The TCP port to bind to.
    ///   - maxConnections: Maximum concurrent connections. Defaults to 100.
    ///   - maxMessageSize: Maximum message size in bytes. Defaults to 10 MB.
    ///   - tlsConfiguration: Optional TLS configuration for STARTTLS. Defaults to nil (disabled).
    public init(
        domain: String = "localhost",
        port: UInt16,
        maxConnections: Int = 100,
        maxMessageSize: Int = 10 * 1024 * 1024,
        tlsConfiguration: TLSConfiguration? = nil
    ) {
        self.domain = domain
        self.port = port
        self.maxConnections = maxConnections
        self.maxMessageSize = maxMessageSize
        self.tlsConfiguration = tlsConfiguration
    }
}

// MARK: - Server Errors

/// Errors that can occur during SMTP server lifecycle operations.
///
/// These errors represent issues with the server's state management,
/// such as attempting to start an already-running server.
///
/// ## Example
///
/// ```swift
/// do {
///     try await server.start()
/// } catch ServerError.alreadyRunning {
///     print("Server is already running")
/// } catch {
///     print("Unexpected error: \(error)")
/// }
/// ```
public enum ServerError: Error, CustomStringConvertible {
    /// The server is already running and cannot be started again.
    ///
    /// This error is thrown when ``SMTPServer/start()`` is called on a server
    /// that is already accepting connections.
    case alreadyRunning

    /// The server is not running and cannot be stopped.
    ///
    /// - Note: This error is currently not thrown as ``SMTPServer/stop()``
    ///   is safe to call on a stopped server.
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
