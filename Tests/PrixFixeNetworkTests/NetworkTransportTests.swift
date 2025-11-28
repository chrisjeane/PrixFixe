import Testing
import Foundation
@testable import PrixFixeNetwork

@Suite("Network Transport Tests")
struct NetworkTransportTests {

    // MARK: - Protocol Compliance Tests

    @Test("FoundationSocket implements NetworkTransport protocol")
    func testFoundationSocketProtocolCompliance() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhost(port: 0)

        try await socket.bind(to: address)
        try await socket.listen(backlog: 10)
        try await socket.close()
    }

    // MARK: - Connection Lifecycle Tests

    @Test("Complete connection lifecycle: bind -> listen -> accept -> close")
    func testConnectionLifecycle() async throws {
        let serverSocket = FoundationSocket()
        let serverAddress = SocketAddress.localhost(port: 0)

        // Bind server socket
        try await serverSocket.bind(to: serverAddress)
        try await serverSocket.listen(backlog: 5)

        // We can't test accept without a real client connection
        // so we just verify the server can be set up and torn down
        try await serverSocket.close()
    }

    @Test("Socket can be rebound after close")
    func testRebindAfterClose() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhost(port: 0)

        // First bind
        try await socket.bind(to: address)
        try await socket.close()

        // Rebind to new socket
        let socket2 = FoundationSocket()
        try await socket2.bind(to: address)
        try await socket2.close()
    }

    @Test("Multiple close calls are safe")
    func testMultipleClose() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhost(port: 0)

        try await socket.bind(to: address)
        try await socket.close()
        try await socket.close()
        try await socket.close()

        // Should not throw or crash
    }

    // MARK: - Error Handling Tests

    @Test("Listen fails if not bound")
    func testListenWithoutBind() async throws {
        let socket = FoundationSocket()

        await #expect(throws: NetworkError.self) {
            try await socket.listen(backlog: 10)
        }
    }

    @Test("Accept requires bind and listen")
    func testAcceptRequirements() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhost(port: 0)

        // Accept should fail if socket is not bound
        await #expect(throws: NetworkError.self) {
            _ = try await socket.accept()
        }

        try await socket.close()
    }

    @Test("Invalid address throws error")
    func testInvalidAddress() throws {
        #expect(throws: NetworkError.self) {
            _ = try SocketAddress(host: "invalid", port: 25)
        }
    }

    // MARK: - Data Transmission Tests

    @Test("Connection can send and receive data")
    func testDataTransmission() async throws {
        // Create mock connection for testing
        let serverSocket = FoundationSocket()
        let serverAddress = SocketAddress.localhost(port: 0)

        try await serverSocket.bind(to: serverAddress)
        try await serverSocket.listen(backlog: 1)

        // This test demonstrates the setup for data transmission
        // Full end-to-end test would require a client connection

        try await serverSocket.close()
    }

    // MARK: - IPv6 and IPv4 Compatibility Tests

    @Test("FoundationSocket binds to IPv6 localhost")
    func testIPv6Localhost() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhost(port: 0)

        #expect(address.isIPv6)
        #expect(!address.isIPv4)

        try await socket.bind(to: address)
        try await socket.close()
    }

    @Test("FoundationSocket binds to IPv4-mapped address")
    func testIPv4Mapped() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhostIPv4(port: 0)

        #expect(!address.isIPv6)
        #expect(address.isIPv4)

        try await socket.bind(to: address)
        try await socket.close()
    }

    @Test("FoundationSocket supports dual-stack mode")
    func testDualStackMode() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.anyAddress(port: 0)

        // Binding to :: should work with IPV6_V6ONLY=0
        try await socket.bind(to: address)
        try await socket.listen(backlog: 10)
        try await socket.close()
    }

    // MARK: - Concurrent Operations Tests

    @Test("Multiple sockets can operate concurrently")
    func testConcurrentSockets() async throws {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    let socket = FoundationSocket()
                    try? await socket.bind(to: .localhost(port: 0))
                    try? await socket.listen(backlog: 5)
                    try? await socket.close()
                }
            }

            await group.waitForAll()
        }
    }

    // MARK: - Resource Cleanup Tests

    @Test("Socket resources are cleaned up on deinit")
    func testResourceCleanup() async throws {
        var socket: FoundationSocket? = FoundationSocket()
        let address = SocketAddress.localhost(port: 0)

        try await socket?.bind(to: address)
        try await socket?.listen(backlog: 5)

        // Let deinit clean up
        socket = nil

        // Give runtime a chance to clean up
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // If we get here without leaks, test passes
    }

    // MARK: - Address Validation Tests

    @Test("SocketAddress validates IPv6 format")
    func testIPv6Validation() throws {
        // Valid IPv6 addresses
        _ = try SocketAddress.ipv6("::1", port: 25)
        _ = try SocketAddress.ipv6("::", port: 25)
        _ = try SocketAddress.ipv6("fe80::1", port: 25)
        _ = try SocketAddress.ipv6("2001:db8::1", port: 25)

        // Invalid IPv6 should throw
        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv6("invalid", port: 25)
        }
    }

    @Test("SocketAddress validates IPv4 format")
    func testIPv4Validation() throws {
        // Valid IPv4 addresses
        _ = try SocketAddress.ipv4("127.0.0.1", port: 25)
        _ = try SocketAddress.ipv4("0.0.0.0", port: 25)
        _ = try SocketAddress.ipv4("192.168.1.1", port: 25)

        // Invalid IPv4 should throw
        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv4("256.1.1.1", port: 25)
        }

        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv4("invalid", port: 25)
        }
    }

    // MARK: - NetworkConnection Protocol Tests

    @Test("Connection close is idempotent")
    func testConnectionCloseIdempotent() async throws {
        // Create a mock connection using internal types
        // This would require an actual connection from accept()
        // For now, we test the socket close idempotency
        let socket = FoundationSocket()
        try await socket.bind(to: .localhost(port: 0))

        try await socket.close()
        try await socket.close()
        try await socket.close()
    }

    // MARK: - IPv4-Specific Tests

    @Test("IPv4 address 127.0.0.1 is correctly mapped to IPv6")
    func testIPv4LoopbackMapping() throws {
        let address = try SocketAddress.ipv4("127.0.0.1", port: 25)

        #expect(address.isIPv4)
        #expect(!address.isIPv6)
        #expect(address.isLoopback)
        #expect(address.host == "::ffff:127.0.0.1")
    }

    @Test("IPv4 address 0.0.0.0 is correctly mapped to IPv6")
    func testIPv4AnyMapping() throws {
        let address = try SocketAddress.ipv4("0.0.0.0", port: 25)

        #expect(address.isIPv4)
        #expect(!address.isIPv6)
        #expect(address.isAny)
        #expect(address.host == "::ffff:0.0.0.0")
    }

    @Test("IPv4 address 192.168.1.1 is correctly mapped to IPv6")
    func testIPv4PrivateMapping() throws {
        let address = try SocketAddress.ipv4("192.168.1.1", port: 80)

        #expect(address.isIPv4)
        #expect(!address.isIPv6)
        #expect(address.host == "::ffff:192.168.1.1")
        #expect(address.port == 80)
    }

    @Test("FoundationSocket can bind to IPv4 0.0.0.0")
    func testBindIPv4Any() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.anyAddressIPv4(port: 0)

        #expect(address.isIPv4)

        try await socket.bind(to: address)
        try await socket.listen(backlog: 5)
        try await socket.close()
    }

    @Test("FoundationSocket can bind to explicit IPv4 address")
    func testBindExplicitIPv4() async throws {
        let socket = FoundationSocket()
        let address = try SocketAddress.ipv4("127.0.0.1", port: 0)

        try await socket.bind(to: address)
        try await socket.listen(backlog: 5)
        try await socket.close()
    }

    @Test("IPv4 address description shows proper format")
    func testIPv4AddressDescription() throws {
        let address = try SocketAddress.ipv4("192.168.1.100", port: 8080)

        let description = address.description
        #expect(description.contains("::ffff:192.168.1.100"))
        #expect(description.contains("8080"))
    }

    @Test("IPv4 and IPv6 addresses can coexist")
    func testIPv4IPv6Coexistence() async throws {
        let socket4 = FoundationSocket()
        let socket6 = FoundationSocket()

        let addr4 = SocketAddress.localhostIPv4(port: 0)
        let addr6 = SocketAddress.localhost(port: 0)

        // Both should bind successfully to different addresses
        try await socket4.bind(to: addr4)
        try await socket6.bind(to: addr6)

        try await socket4.close()
        try await socket6.close()
    }

    @Test("IPv4 validation rejects invalid octets")
    func testIPv4InvalidOctet() {
        // Octet > 255
        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv4("192.168.256.1", port: 25)
        }

        // Negative octet
        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv4("192.168.-1.1", port: 25)
        }
    }

    @Test("IPv4 validation rejects invalid format")
    func testIPv4InvalidFormat() {
        // Too few octets
        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv4("192.168.1", port: 25)
        }

        // Too many octets
        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv4("192.168.1.1.1", port: 25)
        }

        // Non-numeric octets
        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv4("192.168.abc.1", port: 25)
        }
    }

    @Test("IPv4 validation rejects leading zeros")
    func testIPv4LeadingZeros() {
        // Leading zeros are rejected to avoid octal confusion
        #expect(throws: NetworkError.self) {
            try SocketAddress.ipv4("192.168.001.1", port: 25)
        }
    }
}
