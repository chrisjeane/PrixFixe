/// PrixFixeNetwork - Networking Abstractions
///
/// Provides platform-agnostic networking abstractions for socket operations,
/// with platform-specific implementations for Linux, macOS, and iOS.

import Foundation

/// Protocol defining a network transport abstraction for SMTP server operations
public protocol NetworkTransport: Sendable {
    /// The address type used by this transport
    associatedtype Address: NetworkAddress

    /// Bind the transport to the specified address
    /// - Parameter address: The address to bind to
    func bind(to address: Address) async throws

    /// Start listening for incoming connections
    /// - Parameter backlog: Maximum length of the queue of pending connections
    func listen(backlog: Int) async throws

    /// Accept an incoming connection
    /// - Returns: A new connection for the accepted client
    func accept() async throws -> any NetworkConnection

    /// Close the transport and release resources
    func close() async throws
}

/// Protocol defining a network connection abstraction
public protocol NetworkConnection: Sendable {
    /// Read data from the connection
    /// - Parameter maxBytes: Maximum number of bytes to read
    /// - Returns: The data read from the connection
    func read(maxBytes: Int) async throws -> Data

    /// Write data to the connection
    /// - Parameter data: The data to write
    func write(_ data: Data) async throws

    /// Close the connection
    func close() async throws

    /// The remote address of the connection
    var remoteAddress: any NetworkAddress { get }

    /// Upgrade this connection to use TLS encryption
    ///
    /// This method performs an opportunistic TLS upgrade on an existing plaintext connection.
    /// The upgrade is typically triggered by the SMTP STARTTLS command.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let tlsConfig = TLSConfiguration(
    ///     certificateSource: .file(
    ///         certificatePath: "/path/to/cert.pem",
    ///         privateKeyPath: "/path/to/key.pem"
    ///     )
    /// )
    ///
    /// try await connection.startTLS(configuration: tlsConfig)
    /// // Connection is now encrypted
    /// ```
    ///
    /// - Parameter configuration: TLS configuration including certificate and key
    /// - Throws: `NetworkError.tlsUpgradeFailed` if the upgrade fails
    /// - Throws: `NetworkError.invalidCertificate` if certificate is invalid
    /// - Throws: `NetworkError.tlsHandshakeFailed` if handshake fails
    /// - Throws: `NetworkError.tlsAlreadyActive` if TLS is already active
    ///
    /// - Important: Any buffered plaintext data must be cleared before calling this method
    ///   to prevent security vulnerabilities.
    ///
    /// - Note: After a successful TLS upgrade, all subsequent read and write operations
    ///   will be encrypted.
    func startTLS(configuration: TLSConfiguration) async throws

    /// Whether TLS is currently active on this connection
    ///
    /// Returns true if the connection has been successfully upgraded to TLS,
    /// false if the connection is still plaintext.
    var isTLSActive: Bool { get async }
}

// MARK: - Default Implementation

extension NetworkConnection {
    /// Default implementation that throws "not supported"
    ///
    /// Connection types that don't support TLS will use this default implementation.
    public func startTLS(configuration: TLSConfiguration) async throws {
        throw NetworkError.tlsUpgradeFailed("TLS not supported by this connection type")
    }

    /// Default implementation returns false
    public var isTLSActive: Bool {
        get async { false }
    }
}

/// Protocol defining a network address abstraction
public protocol NetworkAddress: Sendable, CustomStringConvertible {
    /// Whether this is an IPv4 address
    var isIPv4: Bool { get }

    /// Whether this is an IPv6 address
    var isIPv6: Bool { get }
}
