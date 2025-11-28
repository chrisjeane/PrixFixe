/// Tests to verify SocketFactory workaround for macOS 26.1 beta bug

import Testing
import Foundation

@testable import PrixFixeNetwork
@testable import PrixFixePlatform

@Suite("SocketFactory Workaround Tests")
struct SocketFactoryWorkaroundTests {

    @Test("SocketFactory uses FoundationSocket on macOS 26.1 beta")
    func testWorkaroundActive() {
        #if os(macOS)
        let caps = PlatformCapabilities.current

        if caps.hasNetworkFrameworkBug {
            // Bug detected - should use FoundationSocket
            let transportType = SocketFactory.defaultTransportType
            #expect(transportType == .foundation,
                   "Expected FoundationSocket workaround when bug is detected")

            let transport = SocketFactory.createTransport()
            #expect(transport is FoundationSocket,
                   "Expected FoundationSocket instance when bug is detected")

            print("✓ Workaround active: Using FoundationSocket instead of NetworkFrameworkSocket")
        } else {
            print("ℹ️ Bug not detected on this macOS version - NetworkFrameworkSocket will be used")
        }
        #endif
    }

    @Test("FoundationSocket works with bind and listen")
    func testFoundationSocketWorks() async throws {
        // Create FoundationSocket explicitly (bypassing factory)
        let socket = FoundationSocket()

        // Test bind to ephemeral port
        try await socket.bind(to: .localhost(port: 0))

        // Test listen
        try await socket.listen(backlog: 5)

        // Clean up
        try await socket.close()

        print("✓ FoundationSocket bind/listen working")
    }

    @Test("SocketFactory creates appropriate transport type")
    func testFactoryCreatesCorrectType() {
        // Use the factory
        let transport = SocketFactory.createTransport()

        #if os(macOS)
        let caps = PlatformCapabilities.current
        if caps.hasNetworkFrameworkBug {
            // On macOS 26.1 beta with the bug, should create FoundationSocket
            #expect(transport is FoundationSocket,
                   "Expected FoundationSocket on macOS 26.1 beta")
            print("✓ SocketFactory creating FoundationSocket (workaround active)")
        } else {
            #if canImport(Network)
            if #available(macOS 13.0, *) {
                #expect(transport is NetworkFrameworkSocket,
                       "Expected NetworkFrameworkSocket on stable macOS")
                print("✓ SocketFactory creating NetworkFrameworkSocket (no bug)")
            }
            #endif
        }
        #endif
    }
}
