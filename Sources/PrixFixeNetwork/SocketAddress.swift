/// IPv6-first socket address implementation with IPv4 compatibility
///
/// This implementation prioritizes IPv6 addressing while supporting IPv4 through
/// IPv4-mapped IPv6 addresses (::ffff:x.x.x.x format).

import Foundation

/// Represents a network socket address (IPv6 or IPv4-mapped IPv6)
public struct SocketAddress: NetworkAddress, Sendable, Hashable {
    /// The address family
    public enum Family: Sendable, Hashable {
        case ipv6
        case ipv4Mapped  // IPv4 addresses mapped to IPv6 (::ffff:x.x.x.x)
    }

    /// The address family of this socket address
    public let family: Family

    /// The string representation of the IP address
    public let host: String

    /// The port number (0-65535)
    public let port: UInt16

    /// Zone identifier for IPv6 link-local addresses (e.g., "en0" in "fe80::1%en0")
    public let zoneID: String?

    // MARK: - Initializers

    /// Create a socket address from host and port
    /// - Parameters:
    ///   - host: The IP address as a string (IPv6 or IPv4)
    ///   - port: The port number
    ///   - zoneID: Optional zone identifier for IPv6 link-local addresses
    public init(host: String, port: UInt16, zoneID: String? = nil) throws {
        self.port = port
        self.zoneID = zoneID

        // Attempt to parse as IPv6 first
        if let parsedHost = Self.parseIPv6(host) {
            self.family = .ipv6
            self.host = parsedHost
        } else if let ipv4Host = Self.parseIPv4(host) {
            // Convert IPv4 to IPv4-mapped IPv6
            self.family = .ipv4Mapped
            self.host = "::ffff:\(ipv4Host)"
        } else {
            throw NetworkError.invalidAddress("Invalid IP address: \(host)")
        }
    }

    /// Create an IPv6 socket address
    /// - Parameters:
    ///   - ipv6: The IPv6 address string
    ///   - port: The port number
    ///   - zoneID: Optional zone identifier
    public static func ipv6(_ ipv6: String, port: UInt16, zoneID: String? = nil) throws -> SocketAddress {
        guard let parsed = parseIPv6(ipv6) else {
            throw NetworkError.invalidAddress("Invalid IPv6 address: \(ipv6)")
        }

        return SocketAddress.__unsafeInit(family: .ipv6, host: parsed, port: port, zoneID: zoneID)
    }

    /// Create an IPv4-mapped IPv6 socket address
    /// - Parameters:
    ///   - ipv4: The IPv4 address string
    ///   - port: The port number
    public static func ipv4(_ ipv4: String, port: UInt16) throws -> SocketAddress {
        guard let parsed = parseIPv4(ipv4) else {
            throw NetworkError.invalidAddress("Invalid IPv4 address: \(ipv4)")
        }

        return SocketAddress.__unsafeInit(
            family: .ipv4Mapped,
            host: "::ffff:\(parsed)",
            port: port,
            zoneID: nil
        )
    }

    /// Unsafe initializer for internal use after validation.
    ///
    /// - Warning: This method bypasses all validation and creates a `SocketAddress` with the provided values directly.
    ///   It assumes the caller has already validated that:
    ///   - The `host` string is a valid IPv6 address or IPv4-mapped IPv6 address
    ///   - The `family` correctly matches the format of `host`
    ///   - The `zoneID` is valid for link-local addresses (or nil otherwise)
    ///
    /// - Important: Using this method with invalid data will create a malformed `SocketAddress` that will
    ///   fail when used with actual socket operations. Only use this after performing validation with
    ///   `parseIPv6()` or `parseIPv4()`.
    ///
    /// - Parameters:
    ///   - family: The address family (must match the host format)
    ///   - host: A pre-validated IP address string
    ///   - port: The port number (0-65535)
    ///   - zoneID: Optional zone identifier for link-local addresses
    ///
    /// - Returns: A `SocketAddress` with the provided values (no validation performed)
    private static func __unsafeInit(family: Family, host: String, port: UInt16, zoneID: String?) -> SocketAddress {
        SocketAddress(unsafeFamily: family, unsafeHost: host, port: port, zoneID: zoneID)
    }

    /// Private initializer that skips all validation.
    ///
    /// - Warning: This is an unsafe initializer that bypasses validation. It should only be called
    ///   from `__unsafeInit()` after proper validation has been performed, or from predefined
    ///   factory methods like `localhost()` where the values are hardcoded and known to be valid.
    ///
    /// - Important: This initializer is marked private to prevent external callers from creating
    ///   invalid `SocketAddress` instances. All public APIs must validate their inputs before
    ///   using this initializer.
    ///
    /// The safety contract for this initializer:
    /// - Caller MUST ensure `unsafeHost` is a syntactically valid IPv6 address
    /// - Caller MUST ensure `unsafeFamily` correctly describes the address type in `unsafeHost`
    /// - Caller MUST ensure `zoneID` is valid for the address (or nil for non-link-local)
    /// - Caller MUST ensure `port` is within valid range (0-65535, enforced by UInt16 type)
    ///
    /// - Parameters:
    ///   - unsafeFamily: The address family (assumed to match unsafeHost)
    ///   - unsafeHost: An IP address string (assumed to be pre-validated)
    ///   - port: The port number
    ///   - zoneID: Optional zone identifier for link-local addresses
    private init(unsafeFamily: Family, unsafeHost: String, port: UInt16, zoneID: String?) {
        self.family = unsafeFamily
        self.host = unsafeHost
        self.port = port
        self.zoneID = zoneID
    }

    // MARK: - Predefined Addresses

    /// IPv6 loopback address (::1) on the specified port
    public static func localhost(port: UInt16) -> SocketAddress {
        SocketAddress(unsafeFamily: .ipv6, unsafeHost: "::1", port: port, zoneID: nil)
    }

    /// IPv6 any address (::) on the specified port - binds to all interfaces
    public static func anyAddress(port: UInt16) -> SocketAddress {
        SocketAddress(unsafeFamily: .ipv6, unsafeHost: "::", port: port, zoneID: nil)
    }

    /// IPv4 loopback (127.0.0.1) as IPv4-mapped IPv6
    public static func localhostIPv4(port: UInt16) -> SocketAddress {
        SocketAddress(unsafeFamily: .ipv4Mapped, unsafeHost: "::ffff:127.0.0.1", port: port, zoneID: nil)
    }

    /// IPv4 any address (0.0.0.0) as IPv4-mapped IPv6
    public static func anyAddressIPv4(port: UInt16) -> SocketAddress {
        SocketAddress(unsafeFamily: .ipv4Mapped, unsafeHost: "::ffff:0.0.0.0", port: port, zoneID: nil)
    }

    // MARK: - NetworkAddress Protocol

    public var isIPv4: Bool {
        family == .ipv4Mapped
    }

    public var isIPv6: Bool {
        family == .ipv6
    }

    /// Whether this is a loopback address (::1 or 127.0.0.1)
    public var isLoopback: Bool {
        host == "::1" || host == "::ffff:127.0.0.1"
    }

    /// Whether this is an any/wildcard address (:: or 0.0.0.0)
    public var isAny: Bool {
        host == "::" || host == "::ffff:0.0.0.0"
    }

    /// Whether this is a link-local address (fe80::/10)
    public var isLinkLocal: Bool {
        host.hasPrefix("fe80:")
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        if let zone = zoneID {
            return "[\(host)%\(zone)]:\(port)"
        } else {
            return "[\(host)]:\(port)"
        }
    }

    // MARK: - Parsing

    /// Parse an IPv6 address, normalizing its format
    private static func parseIPv6(_ string: String) -> String? {
        // Remove zone ID if present for parsing
        let (addressPart, _) = splitZoneID(string)

        // Basic IPv6 validation patterns
        let segments = addressPart.components(separatedBy: ":")

        // IPv6 must have at least 2 colons
        guard segments.count >= 2 else { return nil }

        // Check for "::" compression - can only appear ONCE
        let hasCompression = addressPart.contains("::")

        if hasCompression {
            // Count occurrences of "::" - should be exactly 1
            let compressionCount = addressPart.components(separatedBy: "::").count - 1
            guard compressionCount == 1 else { return nil }
        }

        // Maximum 8 segments (or fewer with compression)
        if !hasCompression && segments.count != 8 {
            return nil
        }

        if hasCompression && segments.count > 8 {
            return nil
        }

        // Validate each segment (hex digits, max 4 chars)
        for segment in segments where !segment.isEmpty {
            // Check if it's a potential IPv4-mapped suffix (e.g., in ::ffff:192.0.2.1)
            if segment.contains(".") {
                // Validate as IPv4
                guard parseIPv4(segment) != nil else { return nil }
                continue
            }

            // Validate as hex segment
            guard segment.count <= 4 else { return nil }
            guard segment.allSatisfy({ $0.isHexDigit }) else { return nil }
        }

        // Return normalized form (we keep the input format for now)
        return addressPart
    }

    /// Parse an IPv4 address
    private static func parseIPv4(_ string: String) -> String? {
        let octets = string.components(separatedBy: ".")

        guard octets.count == 4 else { return nil }

        for octet in octets {
            // Each octet must be a valid number 0-255
            guard UInt8(octet, radix: 10) != nil else { return nil }

            // Reject leading zeros (except "0" itself)
            if octet.count > 1 && octet.hasPrefix("0") {
                return nil
            }
        }

        return string
    }

    /// Split address and zone ID (e.g., "fe80::1%en0" -> ("fe80::1", "en0"))
    private static func splitZoneID(_ address: String) -> (address: String, zoneID: String?) {
        if let percentIndex = address.firstIndex(of: "%") {
            let addr = String(address[..<percentIndex])
            let zone = String(address[address.index(after: percentIndex)...])
            return (addr, zone)
        }
        return (address, nil)
    }
}

// MARK: - Network Errors

public enum NetworkError: Error, Sendable, CustomStringConvertible {
    case invalidAddress(String)
    case bindFailed(String)
    case listenFailed(String)
    case acceptFailed(String)
    case connectionClosed
    case readFailed(String)
    case writeFailed(String)
    case timeout
    case invalidState(String)

    public var description: String {
        switch self {
        case .invalidAddress(let msg):
            return "Invalid address: \(msg)"
        case .bindFailed(let msg):
            return "Bind failed: \(msg)"
        case .listenFailed(let msg):
            return "Listen failed: \(msg)"
        case .acceptFailed(let msg):
            return "Accept failed: \(msg)"
        case .connectionClosed:
            return "Connection closed"
        case .readFailed(let msg):
            return "Read failed: \(msg)"
        case .writeFailed(let msg):
            return "Write failed: \(msg)"
        case .timeout:
            return "Operation timed out"
        case .invalidState(let msg):
            return "Invalid state: \(msg)"
        }
    }
}
