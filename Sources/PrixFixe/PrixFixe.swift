/// # PrixFixe - Lightweight Embedded SMTP Server
///
/// A cross-platform SMTP server library for Swift supporting Linux, macOS, and iOS.
///
/// ## Overview
///
/// PrixFixe is a lightweight, embeddable SMTP server designed to receive email messages
/// in Swift applications. It provides RFC 5321 core compliance with modern IPv6 support
/// and automatic platform-specific transport selection.
///
/// The library is designed to be embedded in applications that need to receive emails,
/// such as development tools, testing frameworks, IoT devices, or desktop applications.
///
/// ## Getting Started
///
/// ### Basic Server Setup
///
/// Create and start an SMTP server with minimal configuration:
///
/// ```swift
/// import PrixFixe
///
/// // Create server with default configuration
/// let server = SMTPServer(configuration: .default)
///
/// // Set up message handler
/// server.messageHandler = { message in
///     print("Received email from: \(message.from)")
///     print("Recipients: \(message.recipients)")
///     print("Data: \(String(data: message.data, encoding: .utf8) ?? "")")
/// }
///
/// // Start the server
/// try await server.start()
/// ```
///
/// ### Custom Configuration
///
/// Configure the server for your specific needs:
///
/// ```swift
/// let config = ServerConfiguration(
///     domain: "mail.example.com",
///     port: 2525,
///     maxConnections: 100,
///     maxMessageSize: 10 * 1024 * 1024  // 10 MB
/// )
///
/// let server = SMTPServer(configuration: config)
/// ```
///
/// ## Key Features
///
/// - **Multi-platform**: Runs on Linux, macOS, and iOS
/// - **IPv6-first**: Built-in IPv6 support with IPv4-mapped address compatibility
/// - **Modern Swift**: Leverages async/await and actors for concurrency safety
/// - **Embeddable**: Library-first design for easy integration into host applications
/// - **RFC 5321 Compliant**: Implements core SMTP commands (HELO, EHLO, MAIL FROM, RCPT TO, DATA, QUIT, RSET, NOOP)
/// - **Platform-Aware**: Automatic selection of optimal network transport (Network.framework or Foundation sockets)
/// - **Production-Ready**: Connection timeouts, message size limits, and comprehensive error handling
/// - **Zero Dependencies**: Pure Swift with only Foundation (and Network.framework on Apple platforms)
///
/// ## Architecture
///
/// PrixFixe is organized into focused modules:
///
/// - ``PrixFixeCore``: SMTP protocol implementation, state machine, and server lifecycle
/// - ``PrixFixeNetwork``: Platform-agnostic networking abstractions with platform-specific implementations
/// - ``PrixFixeMessage``: Email message structures and handling
/// - ``PrixFixePlatform``: Platform detection and capability querying
///
/// ## Platform Support
///
/// | Platform | Minimum Version | Network Implementation | Status |
/// |----------|----------------|----------------------|--------|
/// | Linux | Ubuntu 22.04 LTS | Foundation Sockets (POSIX) | Supported |
/// | macOS | 13.0 (Ventura) | Network.framework | Supported |
/// | iOS | 16.0 | Network.framework | Supported |
///
/// The library automatically selects the optimal network transport for your platform using ``SocketFactory``.
///
/// ## Topics
///
/// ### Essentials
///
/// - ``SMTPServer``
/// - ``ServerConfiguration``
/// - ``EmailMessage``
///
/// ### Message Handling
///
/// - ``EmailAddress``
/// - ``EmailMessage``
///
/// ### Configuration
///
/// - ``ServerConfiguration``
/// - ``SessionConfiguration``
///
/// ### Errors
///
/// - ``ServerError``
/// - ``SMTPError``
/// - ``NetworkError``
///
/// ### Networking
///
/// - ``NetworkTransport``
/// - ``NetworkConnection``
/// - ``SocketAddress``
/// - ``SocketFactory``
///
/// ### Platform Detection
///
/// - ``Platform``
/// - ``PlatformCapabilities``

// Re-export all public APIs from submodules
@_exported import PrixFixeCore
@_exported import PrixFixeNetwork
@_exported import PrixFixeMessage
@_exported import PrixFixePlatform
