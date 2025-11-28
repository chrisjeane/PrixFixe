/// PrixFixePlatform - Platform Detection and Capabilities
///
/// Provides platform detection and capability querying for Linux, macOS, and iOS.

import Foundation

/// Enumeration of supported platforms
public enum Platform: Sendable {
    case linux
    case macOS
    case iOS

    /// The current platform
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

/// Platform capabilities and constraints
public struct PlatformCapabilities: Sendable {
    /// Whether Network.framework is available
    public let hasNetworkFramework: Bool

    /// Whether running on iOS with background limitations
    public let hasBackgroundLimitations: Bool

    /// Recommended maximum concurrent connections for this platform
    public let recommendedMaxConnections: Int

    /// Get capabilities for the current platform
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
