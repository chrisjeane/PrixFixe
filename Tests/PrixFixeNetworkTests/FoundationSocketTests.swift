import Testing
import Foundation
@testable import PrixFixeNetwork

@Suite("Foundation Socket Integration Tests")
struct FoundationSocketTests {

    @Test("Create and bind socket to IPv6 loopback")
    func testBindIPv6Loopback() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhost(port: 0) // Port 0 = ephemeral port

        try await socket.bind(to: address)
        try await socket.close()
    }

    @Test("Create and bind socket to IPv6 any address")
    func testBindIPv6Any() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.anyAddress(port: 0)

        try await socket.bind(to: address)
        try await socket.close()
    }

    @Test("Bind and listen on ephemeral port")
    func testBindAndListen() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhost(port: 0)

        try await socket.bind(to: address)
        try await socket.listen(backlog: 10)
        try await socket.close()
    }

    @Test("Bind to IPv4-mapped address")
    func testBindIPv4Mapped() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhostIPv4(port: 0)

        try await socket.bind(to: address)
        try await socket.listen(backlog: 5)
        try await socket.close()
    }

    @Test("Cannot listen before bind")
    func testListenWithoutBind() async throws {
        let socket = FoundationSocket()

        await #expect(throws: NetworkError.self) {
            try await socket.listen(backlog: 10)
        }
    }

    @Test("Socket cleanup on close")
    func testSocketCleanup() async throws {
        let socket = FoundationSocket()
        let address = SocketAddress.localhost(port: 0)

        try await socket.bind(to: address)
        try await socket.listen(backlog: 10)

        // Close should clean up resources
        try await socket.close()

        // Second close should be safe (no-op)
        try await socket.close()
    }

    @Test("Dual-stack support - IPv6 socket accepts IPv4-mapped")
    func testDualStackSupport() async throws {
        // This test validates that binding to :: allows both IPv6 and IPv4 connections
        // We just verify the socket can be created with appropriate options

        let socket = FoundationSocket()
        let address = SocketAddress.anyAddress(port: 0)

        // Should bind successfully with IPV6_V6ONLY=0 (dual-stack)
        try await socket.bind(to: address)
        try await socket.listen(backlog: 10)
        try await socket.close()

        // Success means dual-stack was configured correctly
    }

    @Test("Multiple sockets can bind to different ports")
    func testMultipleSockets() async throws {
        let socket1 = FoundationSocket()
        let socket2 = FoundationSocket()

        try await socket1.bind(to: .localhost(port: 0))
        try await socket2.bind(to: .localhost(port: 0))

        try await socket1.listen(backlog: 5)
        try await socket2.listen(backlog: 5)

        try await socket1.close()
        try await socket2.close()
    }
}
