/// PrixFixePlatform - Platform Detection and Capabilities
///
/// Provides platform detection and capability querying for Linux, macOS, and iOS.
///
/// ## Overview
///
/// This module enables runtime platform detection and capability querying,
/// allowing you to adapt server behavior based on platform constraints.
///
/// ## Example
///
/// ```swift
/// import PrixFixePlatform
///
/// // Detect current platform
/// switch Platform.current {
/// case .linux:
///     print("Running on Linux")
/// case .macOS:
///     print("Running on macOS")
/// case .iOS:
///     print("Running on iOS")
/// }
///
/// // Query platform capabilities
/// let caps = PlatformCapabilities.current
/// print("Network.framework: \(caps.hasNetworkFramework)")
/// print("Recommended max connections: \(caps.recommendedMaxConnections)")
/// ```

import Foundation

/// Represents the current execution platform.
///
/// Use this enumeration to detect which platform your code is running on
/// and adapt behavior accordingly.
///
/// ## Example
///
/// ```swift
/// let platform = Platform.current
///
/// switch platform {
/// case .linux:
///     // Linux-specific code
///     print("Using Foundation sockets")
/// case .macOS, .iOS:
///     // Apple platform-specific code
///     print("Using Network.framework")
/// }
/// ```
public enum Platform: Sendable {
    /// Linux operating system
    case linux

    /// macOS operating system
    case macOS

    /// iOS operating system
    case iOS

    /// The current execution platform.
    ///
    /// This property is determined at compile time using conditional compilation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if Platform.current == .iOS {
    ///     // Configure for iOS constraints
    ///     config.maxConnections = 10
    /// }
    /// ```
    public static var current: Platform {
        #if os(Linux)
        return .linux
        #elseif os(macOS)
        return .macOS
        #elseif os(iOS)
        return .iOS
        #else
        #error("Unsupported platform")
        #endif
    }
}

/// Platform-specific capabilities and recommended limits.
///
/// Use this structure to query platform capabilities and adapt your
/// server configuration to platform constraints.
///
/// ## Example
///
/// ```swift
/// let caps = PlatformCapabilities.current
///
/// let config = ServerConfiguration(
///     domain: "mail.example.com",
///     port: 2525,
///     maxConnections: caps.recommendedMaxConnections,
///     maxMessageSize: caps.hasBackgroundLimitations ? 5_000_000 : 10_000_000
/// )
/// ```
public struct PlatformCapabilities: Sendable {
    /// Whether Network.framework is available on this platform.
    ///
    /// Network.framework provides modern, efficient networking on Apple platforms.
    /// - `true` on macOS and iOS
    /// - `false` on Linux
    public let hasNetworkFramework: Bool

    /// Whether the platform has background execution limitations.
    ///
    /// iOS suspends background execution, which affects long-running servers.
    /// - `true` on iOS
    /// - `false` on macOS and Linux
    ///
    /// - Note: On iOS, consider using lower connection limits and implementing
    ///   proper background task handling.
    public let hasBackgroundLimitations: Bool

    /// Recommended maximum number of concurrent connections for this platform.
    ///
    /// These recommendations account for typical platform constraints:
    /// - **Linux/macOS**: 1000 connections (server-class performance)
    /// - **iOS**: 10 connections (mobile device constraints)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = ServerConfiguration(
    ///     maxConnections: PlatformCapabilities.current.recommendedMaxConnections
    /// )
    /// ```
    public let recommendedMaxConnections: Int

    /// Capabilities for the current platform.
    ///
    /// Returns a `PlatformCapabilities` instance configured for the
    /// detected platform with appropriate recommendations.
    public static var current: PlatformCapabilities {
        switch Platform.current {
        case .linux:
            return PlatformCapabilities(
                hasNetworkFramework: false,
                hasBackgroundLimitations: false,
                recommendedMaxConnections: 1000
            )
        case .macOS:
            return PlatformCapabilities(
                hasNetworkFramework: true,
                hasBackgroundLimitations: false,
                recommendedMaxConnections: 1000
            )
        case .iOS:
            return PlatformCapabilities(
                hasNetworkFramework: true,
                hasBackgroundLimitations: true,
                recommendedMaxConnections: 10
            )
        }
    }

    init(hasNetworkFramework: Bool, hasBackgroundLimitations: Bool, recommendedMaxConnections: Int) {
        self.hasNetworkFramework = hasNetworkFramework
        self.hasBackgroundLimitations = hasBackgroundLimitations
        self.recommendedMaxConnections = recommendedMaxConnections
    }
}
