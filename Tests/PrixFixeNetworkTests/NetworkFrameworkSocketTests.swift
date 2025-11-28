/// Tests for Network.framework socket implementation
///
/// These tests validate the NetworkFrameworkSocket on macOS and iOS.

import Testing
import Foundation

@testable import PrixFixeNetwork

#if canImport(Network) && (os(macOS) || os(iOS))
import Network

@Suite("Network.framework Socket Tests")
struct NetworkFrameworkSocketTests {

    @Test("NetworkFrameworkSocket can bind to ephemeral port")
    func testBindEphemeralPort() async throws {
        let socket = NetworkFrameworkSocket()

        // Bind to localhost with ephemeral port (0)
        try await socket.bind(to: .localhost(port: 0))

        // Listen
        try await socket.listen(backlog: 5)

        // Clean up
        try await socket.close()
    }

    @Test("NetworkFrameworkSocket can bind to specific port")
    func testBindSpecificPort() async throws {
        let socket = NetworkFrameworkSocket()

        // Use a high port number to avoid permission issues
        let port: UInt16 = 50000 + UInt16.random(in: 0..<1000)
        try await socket.bind(to: .localhost(port: port))
        try await socket.listen(backlog: 5)

        try await socket.close()
    }

    @Test("NetworkFrameworkSocket can accept connections")
    func testAcceptConnection() async throws {
        let server = NetworkFrameworkSocket()
        let port: UInt16 = 50000 + UInt16.random(in: 0..<1000)

        try await server.bind(to: .localhost(port: port))
        try await server.listen(backlog: 5)

        // Create a client connection in parallel
        let clientTask = Task {
            try await Task.sleep(for: .milliseconds(100))

            let endpoint = NWEndpoint.hostPort(
                host: .ipv6(.loopback),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let connection = NWConnection(to: endpoint, using: .tcp)
            let queue = DispatchQueue(label: "test.client")
            connection.start(queue: queue)

            // Keep connection alive briefly
            try await Task.sleep(for: .milliseconds(500))
            connection.cancel()
        }

        // Accept connection
        let acceptedConnection = try await server.accept()
        #expect(acceptedConnection.remoteAddress.isIPv6 || acceptedConnection.remoteAddress.isIPv4)

        // Clean up
        try await acceptedConnection.close()
        try await server.close()
        try await clientTask.value
    }

    @Test("NetworkFrameworkConnection can read and write data")
    func testConnectionReadWrite() async throws {
        let server = NetworkFrameworkSocket()
        let port: UInt16 = 50000 + UInt16.random(in: 0..<1000)

        try await server.bind(to: .localhost(port: port))
        try await server.listen(backlog: 5)

        let testMessage = "Hello, Network.framework!"
        let testData = testMessage.data(using: .utf8)!

        // Server task
        let serverTask = Task {
            let connection = try await server.accept()

            // Read data
            let receivedData = try await connection.read(maxBytes: 1024)
            #expect(receivedData == testData)

            // Echo it back
            try await connection.write(receivedData)

            try await connection.close()
        }

        // Client task
        let clientTask = Task {
            try await Task.sleep(for: .milliseconds(100))

            let endpoint = NWEndpoint.hostPort(
                host: .ipv6(.loopback),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let connection = NWConnection(to: endpoint, using: .tcp)
            let queue = DispatchQueue(label: "test.client")
            connection.start(queue: queue)

            // Wait for connection to be ready
            try await Task.sleep(for: .milliseconds(200))

            // Send data
            await withCheckedContinuation { continuation in
                connection.send(content: testData, completion: .contentProcessed { _ in
                    continuation.resume()
                })
            }

            // Receive echo
            let receivedData: Data = await withCheckedContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
                    continuation.resume(returning: data ?? Data())
                }
            }

            #expect(receivedData == testData)

            connection.cancel()
        }

        try await serverTask.value
        try await clientTask.value
        try await server.close()
    }

    @Test("NetworkFrameworkSocket supports IPv6 addresses")
    func testIPv6Support() async throws {
        let socket = NetworkFrameworkSocket()

        // Bind to IPv6 localhost
        try await socket.bind(to: .localhost(port: 0))
        try await socket.listen(backlog: 5)

        try await socket.close()
    }

    @Test("NetworkFrameworkSocket supports IPv4-mapped addresses")
    func testIPv4MappedSupport() async throws {
        let socket = NetworkFrameworkSocket()

        // Bind to IPv4 localhost (mapped to IPv6)
        try await socket.bind(to: .localhostIPv4(port: 0))
        try await socket.listen(backlog: 5)

        try await socket.close()
    }

    @Test("NetworkFrameworkSocket can bind to any address")
    func testBindAnyAddress() async throws {
        let socket = NetworkFrameworkSocket()

        // Bind to any address (::)
        try await socket.bind(to: .anyAddress(port: 0))
        try await socket.listen(backlog: 5)

        try await socket.close()
    }

    @Test("NetworkFrameworkSocket properly cleans up on close")
    func testCleanup() async throws {
        let socket = NetworkFrameworkSocket()
        let port: UInt16 = 50000 + UInt16.random(in: 0..<1000)

        try await socket.bind(to: .localhost(port: port))
        try await socket.listen(backlog: 5)
        try await socket.close()

        // Should be able to bind to the same port again
        let socket2 = NetworkFrameworkSocket()
        try await socket2.bind(to: .localhost(port: port))
        try await socket2.listen(backlog: 5)
        try await socket2.close()
    }

    @Test("Multiple connections can be accepted")
    func testMultipleConnections() async throws {
        let server = NetworkFrameworkSocket()
        let port: UInt16 = 50000 + UInt16.random(in: 0..<1000)

        try await server.bind(to: .localhost(port: port))
        try await server.listen(backlog: 5)

        // Create 3 client connections first
        var clients: [NWConnection] = []
        for _ in 0..<3 {
            let endpoint = NWEndpoint.hostPort(
                host: .ipv6(.loopback),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let connection = NWConnection(to: endpoint, using: .tcp)
            let queue = DispatchQueue(label: "test.client.\(clients.count)")
            connection.start(queue: queue)
            clients.append(connection)

            try await Task.sleep(for: .milliseconds(50))
        }

        // Accept 3 connections
        var connectionCount = 0
        for _ in 0..<3 {
            let conn = try await server.accept()
            try await conn.close()
            connectionCount += 1
        }

        #expect(connectionCount == 3)

        // Clean up
        for client in clients {
            client.cancel()
        }
        try await server.close()
    }
}

#endif
