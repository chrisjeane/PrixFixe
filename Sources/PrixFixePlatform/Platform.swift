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

    /// Whether Network.framework has known issues on this OS version.
    ///
    /// Indicates if the current macOS beta version has the NWListener binding bug.
    /// - `true` on macOS 26.1 beta (build 25B78) where NWListener fails with EINVAL
    /// - `false` on all other platforms and versions
    ///
    /// - Note: When this is true, SocketFactory automatically falls back to FoundationSocket
    ///   to ensure reliable operation.
    public let hasNetworkFrameworkBug: Bool

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
                recommendedMaxConnections: 1000,
                hasNetworkFrameworkBug: false
            )
        case .macOS:
            return PlatformCapabilities(
                hasNetworkFramework: true,
                hasBackgroundLimitations: false,
                recommendedMaxConnections: 1000,
                hasNetworkFrameworkBug: detectMacOSBetaBug()
            )
        case .iOS:
            return PlatformCapabilities(
                hasNetworkFramework: true,
                hasBackgroundLimitations: true,
                recommendedMaxConnections: 10,
                hasNetworkFrameworkBug: false
            )
        }
    }

    init(hasNetworkFramework: Bool, hasBackgroundLimitations: Bool, recommendedMaxConnections: Int, hasNetworkFrameworkBug: Bool) {
        self.hasNetworkFramework = hasNetworkFramework
        self.hasBackgroundLimitations = hasBackgroundLimitations
        self.recommendedMaxConnections = recommendedMaxConnections
        self.hasNetworkFrameworkBug = hasNetworkFrameworkBug
    }

    /// Detects if running on macOS 26.1 beta with the NWListener binding bug.
    ///
    /// This function checks the macOS build version to identify the specific beta build
    /// that has a known NWListener regression where binding fails with EINVAL.
    ///
    /// - Returns: `true` if running on macOS 26.1 beta (build 25B78 or similar), `false` otherwise
    private static func detectMacOSBetaBug() -> Bool {
        #if os(macOS) && canImport(Darwin)
        // Primary detection: check build version directly
        // macOS 26.1 beta has build versions starting with "25B"
        if let buildVersion = getBuildVersion() {
            // Known affected builds: 25B78 and potentially other 25B* builds
            if buildVersion.hasPrefix("25B") {
                return true
            }
        }

        // Fallback: check OS version
        // macOS 26.1 might be reported differently by ProcessInfo
        if #available(macOS 15.0, *) {
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion

            // If we see version 26.x or 15.2+, be conservative and assume the bug exists
            if osVersion.majorVersion >= 26 {
                return true
            }

            if osVersion.majorVersion >= 15 && osVersion.minorVersion >= 2 {
                return true
            }
        }
        #endif
        return false
    }

    #if os(macOS) && canImport(Darwin)
    /// Retrieves the macOS build version string.
    ///
    /// Uses `sysctlbyname` to query the kernel for the build version string.
    ///
    /// - Returns: The build version string (e.g., "25B78"), or `nil` if unavailable
    private static func getBuildVersion() -> String? {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        guard size > 0 else { return nil }

        var buildVersion = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &buildVersion, &size, nil, 0) == 0 else {
            return nil
        }

        // Find null terminator and convert to UInt8 array
        let nullTerminatorIndex = buildVersion.firstIndex(of: 0) ?? buildVersion.count
        let bytes = buildVersion[..<nullTerminatorIndex].map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
    #endif
}
