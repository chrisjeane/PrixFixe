import Testing
import Foundation
@testable import PrixFixeNetwork

@Suite("Socket Address Tests")
struct SocketAddressTests {

    // MARK: - IPv6 Address Parsing

    @Test("Parse valid IPv6 loopback address")
    func testIPv6Loopback() throws {
        let addr = try SocketAddress.ipv6("::1", port: 8080)

        #expect(addr.family == .ipv6)
        #expect(addr.host == "::1")
        #expect(addr.port == 8080)
        #expect(addr.isIPv6)
        #expect(!addr.isIPv4)
        #expect(addr.isLoopback)
    }

    @Test("Parse valid IPv6 any address")
    func testIPv6Any() throws {
        let addr = try SocketAddress.ipv6("::", port: 25)

        #expect(addr.family == .ipv6)
        #expect(addr.host == "::")
        #expect(addr.port == 25)
        #expect(addr.isAny)
    }

    @Test("Parse full IPv6 address")
    func testIPv6Full() throws {
        let addr = try SocketAddress.ipv6("2001:0db8:85a3:0000:0000:8a2e:0370:7334", port: 443)

        #expect(addr.family == .ipv6)
        #expect(addr.host == "2001:0db8:85a3:0000:0000:8a2e:0370:7334")
        #expect(addr.port == 443)
        #expect(!addr.isLoopback)
        #expect(!addr.isAny)
    }

    @Test("Parse compressed IPv6 address")
    func testIPv6Compressed() throws {
        let addr = try SocketAddress.ipv6("2001:db8::1", port: 80)

        #expect(addr.family == .ipv6)
        #expect(addr.host == "2001:db8::1")
        #expect(addr.isIPv6)
    }

    @Test("Parse IPv6 link-local address")
    func testIPv6LinkLocal() throws {
        let addr = try SocketAddress.ipv6("fe80::1", port: 22)

        #expect(addr.family == .ipv6)
        #expect(addr.isLinkLocal)
    }

    @Test("Parse IPv6 with zone ID")
    func testIPv6WithZone() throws {
        let addr = try SocketAddress.ipv6("fe80::1", port: 80, zoneID: "en0")

        #expect(addr.family == .ipv6)
        #expect(addr.host == "fe80::1")
        #expect(addr.zoneID == "en0")
        #expect(addr.description.contains("%en0"))
    }

    // MARK: - IPv4-Mapped IPv6

    @Test("Parse IPv4 address as mapped IPv6")
    func testIPv4Mapped() throws {
        let addr = try SocketAddress.ipv4("192.0.2.1", port: 8080)

        #expect(addr.family == .ipv4Mapped)
        #expect(addr.host == "::ffff:192.0.2.1")
        #expect(addr.port == 8080)
        #expect(addr.isIPv4)
        #expect(!addr.isIPv6)
    }

    @Test("Parse IPv4 loopback as mapped IPv6")
    func testIPv4LoopbackMapped() throws {
        let addr = try SocketAddress.ipv4("127.0.0.1", port: 25)

        #expect(addr.family == .ipv4Mapped)
        #expect(addr.host == "::ffff:127.0.0.1")
        #expect(addr.isIPv4)
        #expect(addr.isLoopback)
    }

    @Test("Parse IPv4 any address as mapped IPv6")
    func testIPv4AnyMapped() throws {
        let addr = try SocketAddress.ipv4("0.0.0.0", port: 80)

        #expect(addr.family == .ipv4Mapped)
        #expect(addr.host == "::ffff:0.0.0.0")
        #expect(addr.isAny)
    }

    // MARK: - Predefined Addresses

    @Test("Create localhost address")
    func testLocalhostAddress() {
        let addr = SocketAddress.localhost(port: 2525)

        #expect(addr.host == "::1")
        #expect(addr.port == 2525)
        #expect(addr.isLoopback)
        #expect(addr.isIPv6)
    }

    @Test("Create any address")
    func testAnyAddress() {
        let addr = SocketAddress.anyAddress(port: 8025)

        #expect(addr.host == "::")
        #expect(addr.port == 8025)
        #expect(addr.isAny)
        #expect(addr.isIPv6)
    }

    @Test("Create IPv4 localhost")
    func testLocalhostIPv4() {
        let addr = SocketAddress.localhostIPv4(port: 587)

        #expect(addr.host == "::ffff:127.0.0.1")
        #expect(addr.port == 587)
        #expect(addr.isLoopback)
        #expect(addr.isIPv4)
    }

    @Test("Create IPv4 any address")
    func testAnyAddressIPv4() {
        let addr = SocketAddress.anyAddressIPv4(port: 25)

        #expect(addr.host == "::ffff:0.0.0.0")
        #expect(addr.port == 25)
        #expect(addr.isAny)
        #expect(addr.isIPv4)
    }

    // MARK: - Generic Init (Auto-detect IPv4/IPv6)

    @Test("Generic init with IPv6 address")
    func testGenericInitIPv6() throws {
        let addr = try SocketAddress(host: "2001:db8::1", port: 443)

        #expect(addr.family == .ipv6)
        #expect(addr.host == "2001:db8::1")
        #expect(addr.isIPv6)
    }

    @Test("Generic init with IPv4 address")
    func testGenericInitIPv4() throws {
        let addr = try SocketAddress(host: "192.168.1.1", port: 80)

        #expect(addr.family == .ipv4Mapped)
        #expect(addr.host == "::ffff:192.168.1.1")
        #expect(addr.isIPv4)
    }

    // MARK: - Invalid Addresses

    @Test("Reject invalid IPv6 address")
    func testInvalidIPv6() {
        #expect(throws: NetworkError.self) {
            _ = try SocketAddress.ipv6("invalid", port: 80)
        }

        #expect(throws: NetworkError.self) {
            _ = try SocketAddress.ipv6("gggg::1", port: 80)
        }

        #expect(throws: NetworkError.self) {
            _ = try SocketAddress.ipv6("::1::2", port: 80)
        }
    }

    @Test("Reject invalid IPv4 address")
    func testInvalidIPv4() {
        #expect(throws: NetworkError.self) {
            _ = try SocketAddress.ipv4("256.1.1.1", port: 80)
        }

        #expect(throws: NetworkError.self) {
            _ = try SocketAddress.ipv4("192.168.1", port: 80)
        }

        #expect(throws: NetworkError.self) {
            _ = try SocketAddress.ipv4("192.168.1.1.1", port: 80)
        }

        #expect(throws: NetworkError.self) {
            _ = try SocketAddress.ipv4("invalid", port: 80)
        }
    }

    @Test("Reject IPv4 with leading zeros")
    func testIPv4LeadingZeros() {
        // Leading zeros should be rejected (security: octal interpretation)
        #expect(throws: NetworkError.self) {
            _ = try SocketAddress.ipv4("192.168.001.1", port: 80)
        }
    }

    // MARK: - String Description

    @Test("IPv6 address description format")
    func testIPv6Description() throws {
        let addr = try SocketAddress.ipv6("2001:db8::1", port: 443)
        #expect(addr.description == "[2001:db8::1]:443")
    }

    @Test("IPv6 with zone description format")
    func testIPv6ZoneDescription() throws {
        let addr = try SocketAddress.ipv6("fe80::1", port: 80, zoneID: "en0")
        #expect(addr.description == "[fe80::1%en0]:80")
    }

    @Test("IPv4-mapped description format")
    func testIPv4MappedDescription() throws {
        let addr = try SocketAddress.ipv4("192.0.2.1", port: 25)
        #expect(addr.description == "[::ffff:192.0.2.1]:25")
    }

    // MARK: - Hashable & Equatable

    @Test("Socket addresses are equal when same host and port")
    func testEquality() throws {
        let addr1 = try SocketAddress.ipv6("::1", port: 80)
        let addr2 = try SocketAddress.ipv6("::1", port: 80)
        let addr3 = try SocketAddress.ipv6("::1", port: 443)

        #expect(addr1 == addr2)
        #expect(addr1 != addr3)
    }

    @Test("Socket addresses can be used in sets")
    func testHashable() throws {
        let addr1 = try SocketAddress.ipv6("::1", port: 80)
        let addr2 = try SocketAddress.ipv6("2001:db8::1", port: 80)
        let addr3 = try SocketAddress.ipv4("127.0.0.1", port: 80)

        let set: Set<SocketAddress> = [addr1, addr2, addr3, addr1]
        #expect(set.count == 3) // addr1 appears only once
    }

    // MARK: - Edge Cases

    @Test("Port boundary values")
    func testPortBoundaries() throws {
        let addr1 = try SocketAddress.ipv6("::1", port: 0)
        #expect(addr1.port == 0)

        let addr2 = try SocketAddress.ipv6("::1", port: 65535)
        #expect(addr2.port == 65535)
    }

    @Test("IPv6 address with embedded IPv4")
    func testIPv6EmbeddedIPv4() throws {
        let addr = try SocketAddress.ipv6("::ffff:192.0.2.1", port: 80)
        #expect(addr.family == .ipv6)
        #expect(addr.host == "::ffff:192.0.2.1")
    }

    @Test("Various IPv6 compression formats")
    func testIPv6Compression() throws {
        let formats = [
            "::1",
            "::ffff:192.0.2.1",
            "2001:db8::1",
            "2001:db8::8a2e:370:7334",
            "::2001:db8:1",
            "fe80::"
        ]

        for format in formats {
            let addr = try SocketAddress.ipv6(format, port: 80)
            #expect(addr.family == .ipv6)
        }
    }
}
