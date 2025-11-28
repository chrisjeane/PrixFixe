/// Socket factory for automatic platform-appropriate socket selection.
///
/// `SocketFactory` provides a unified interface for creating network transports
/// while automatically selecting the optimal implementation for the current platform.
///
/// ## Overview
///
/// The factory automatically chooses the best networking implementation:
/// - **macOS 13.0+**: Uses ``NetworkFrameworkSocket`` for optimal performance
/// - **iOS 16.0+**: Uses ``NetworkFrameworkSocket`` (required for iOS)
/// - **Linux**: Uses ``FoundationSocket`` with POSIX sockets
/// - **Older macOS**: Falls back to ``FoundationSocket``
///
/// ## Example
///
/// ```swift
/// // Automatic platform selection
/// let transport = SocketFactory.createTransport()
///
/// // Query which transport will be used
/// print("Using: \(SocketFactory.defaultTransportType.description)")
///
/// // Create specific implementation if needed
/// #if canImport(Network)
/// if #available(macOS 13.0, iOS 16.0, *) {
///     let networkTransport = SocketFactory.createNetworkFrameworkTransport()
/// }
/// #endif
/// ```
///
/// - Note: In most cases, use ``createTransport()`` to let the factory choose the
///   best implementation. Only use specific factory methods if you need a particular
///   implementation for testing or advanced use cases.

import Foundation
#if canImport(Network)
import Network
#endif

/// Factory for creating platform-appropriate network transports.
///
/// Provides static methods to create optimal networking implementations
/// based on the current platform and OS version.
public enum SocketFactory {
    /// Create a network transport suitable for the current platform.
    ///
    /// This is the recommended way to create a transport. The factory automatically
    /// selects the best implementation available on the current platform.
    ///
    /// - Returns: A ``NetworkTransport`` implementation optimized for the current platform.
    ///
    /// ## Platform Selection
    ///
    /// - macOS 13.0+: ``NetworkFrameworkSocket`` (preferred)
    /// - iOS 16.0+: ``NetworkFrameworkSocket`` (required)
    /// - Linux: ``FoundationSocket`` (only option)
    /// - Older macOS: ``FoundationSocket`` (fallback)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let transport = SocketFactory.createTransport()
    /// try await transport.bind(to: .anyAddress(port: 2525))
    /// try await transport.listen(backlog: 100)
    /// ```
    public static func createTransport() -> any NetworkTransport {
        #if canImport(Network)
        if #available(macOS 13.0, iOS 16.0, *) {
            return NetworkFrameworkSocket()
        } else {
            // Fallback for older OS versions
            return FoundationSocket()
        }
        #else
        // Linux or other platforms without Network.framework
        return FoundationSocket()
        #endif
    }

    /// Create a Foundation-based transport explicitly
    ///
    /// Use this when you need a specific implementation regardless of platform,
    /// for example in testing or when you need POSIX socket-level control.
    ///
    /// - Returns: A FoundationSocket instance
    public static func createFoundationTransport() -> FoundationSocket {
        return FoundationSocket()
    }

    #if canImport(Network)
    /// Create a Network.framework-based transport explicitly
    ///
    /// Use this when you need Network.framework features specifically,
    /// such as path monitoring or TLS support (future).
    ///
    /// - Returns: A NetworkFrameworkSocket instance
    /// - Note: Only available on platforms with Network.framework
    @available(macOS 13.0, iOS 16.0, *)
    public static func createNetworkFrameworkTransport() -> NetworkFrameworkSocket {
        return NetworkFrameworkSocket()
    }
    #endif

    /// Query which transport implementation will be used by default
    ///
    /// - Returns: The type of transport that will be created
    public static var defaultTransportType: TransportType {
        #if canImport(Network)
        if #available(macOS 13.0, iOS 16.0, *) {
            return .networkFramework
        } else {
            return .foundation
        }
        #else
        return .foundation
        #endif
    }

    /// Available transport types
    public enum TransportType: String, Sendable {
        case foundation
        case networkFramework

        /// Human-readable description of the transport
        public var description: String {
            switch self {
            case .foundation:
                return "Foundation BSD Sockets"
            case .networkFramework:
                return "Network.framework"
            }
        }

        /// Whether this transport type is available on the current platform
        public var isAvailable: Bool {
            switch self {
            case .foundation:
                return true
            #if canImport(Network)
            case .networkFramework:
                if #available(macOS 13.0, iOS 16.0, *) {
                    return true
                } else {
                    return false
                }
            #else
            case .networkFramework:
                return false
            #endif
            }
        }
    }
}
