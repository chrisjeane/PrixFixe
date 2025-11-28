import Testing
import Foundation
@testable import PrixFixeCore
@testable import PrixFixeNetwork
@testable import PrixFixeMessage

@Suite("SMTP Server Tests")
struct SMTPServerTests {

    // MARK: - Server Lifecycle Tests

    @Test("Server can be created with default configuration")
    func testServerCreation() async {
        let server = SMTPServer(configuration: .default)
        // Server created successfully - test passes
        _ = server
    }

    @Test("Server can be created with custom configuration")
    func testServerCustomConfiguration() async {
        let config = ServerConfiguration(
            domain: "test.example.com",
            port: 2526,
            maxConnections: 50,
            maxMessageSize: 5 * 1024 * 1024
        )
        let server = SMTPServer(configuration: config)
        // Server created successfully - test passes
        _ = server
    }

    @Test("Server can start and stop on ephemeral port")
    func testServerStartStop() async throws {
        let config = ServerConfiguration(
            domain: "test.local",
            port: 0,  // Ephemeral port
            maxConnections: 10,
            maxMessageSize: 1024 * 1024
        )
        let server = SMTPServer(configuration: config)

        // Start server
        let startTask = Task {
            try await server.start()
        }

        // Give the server a moment to start
        try await Task.sleep(for: .milliseconds(100))

        // Stop server
        try await server.stop()

        // Wait for start task to complete
        startTask.cancel()
    }

    @Test("Server rejects double start")
    func testServerRejectsDoubleStart() async throws {
        let config = ServerConfiguration(
            domain: "test.local",
            port: 0,
            maxConnections: 10,
            maxMessageSize: 1024 * 1024
        )
        let server = SMTPServer(configuration: config)

        // Start server in background
        let serverTask = Task {
            try await server.start()
        }

        // Give the server a moment to start
        try await Task.sleep(for: .milliseconds(100))

        // Try to start again - should fail
        await #expect(throws: ServerError.self) {
            try await server.start()
        }

        // Clean up
        try await server.stop()
        serverTask.cancel()
    }

    @Test("Server can stop when not running")
    func testServerStopWhenNotRunning() async throws {
        let server = SMTPServer(configuration: .default)

        // Stop when not running should not throw
        try await server.stop()

        // Test passes if no exception was thrown
    }

    @Test("Server handles rapid start and stop cycles")
    func testRapidStartStopCycles() async throws {
        let config = ServerConfiguration(
            domain: "test.local",
            port: 0,
            maxConnections: 10,
            maxMessageSize: 1024 * 1024
        )

        for _ in 0..<3 {
            let server = SMTPServer(configuration: config)

            let serverTask = Task {
                try await server.start()
            }

            try await Task.sleep(for: .milliseconds(50))
            try await server.stop()
            serverTask.cancel()
        }

        // Test passes if all cycles completed without error
    }

    // MARK: - Configuration Validation Tests

    @Test("Server configuration has sensible defaults")
    func testDefaultConfiguration() {
        let config = ServerConfiguration.default

        #expect(config.domain == "localhost")
        #expect(config.port == 2525)
        #expect(config.maxConnections == 100)
        #expect(config.maxMessageSize == 10 * 1024 * 1024)
    }

    @Test("Server configuration can be customized")
    func testCustomConfiguration() {
        let config = ServerConfiguration(
            domain: "mail.example.com",
            port: 25,
            maxConnections: 200,
            maxMessageSize: 20 * 1024 * 1024
        )

        #expect(config.domain == "mail.example.com")
        #expect(config.port == 25)
        #expect(config.maxConnections == 200)
        #expect(config.maxMessageSize == 20 * 1024 * 1024)
    }

    // MARK: - Message Handler Tests

    @Test("Server accepts message handler")
    func testMessageHandlerSetup() async {
        let server = SMTPServer(configuration: .default)

        await server.setMessageHandler { message in
            // Handler installed successfully
        }

        // Test passes if handler was set without error
    }

    // MARK: - Error Type Tests

    @Test("ServerError.alreadyRunning is public and has description")
    func testServerErrorAlreadyRunning() {
        let error = ServerError.alreadyRunning
        let description = error.description

        #expect(description.contains("already running"))
    }

    @Test("ServerError.notRunning is public and has description")
    func testServerErrorNotRunning() {
        let error = ServerError.notRunning
        let description = error.description

        #expect(description.contains("not running"))
    }

    @Test("ServerError conforms to CustomStringConvertible")
    func testServerErrorCustomStringConvertible() {
        let error: any CustomStringConvertible = ServerError.alreadyRunning
        #expect(!error.description.isEmpty)
    }

    @Test("SMTPError cases are public and have descriptions")
    func testSMTPErrorDescriptions() {
        let errors: [SMTPError] = [
            .connectionClosed,
            .commandTooLong,
            .invalidEncoding,
            .messageTooLarge,
            .connectionTimeout,
            .commandTimeout
        ]

        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }

    @Test("SMTPError.connectionClosed description is meaningful")
    func testSMTPErrorConnectionClosedDescription() {
        let error = SMTPError.connectionClosed
        #expect(error.description.contains("connection"))
        #expect(error.description.contains("closed"))
    }

    @Test("SMTPError.commandTimeout description is meaningful")
    func testSMTPErrorCommandTimeoutDescription() {
        let error = SMTPError.commandTimeout
        #expect(error.description.contains("command"))
        #expect(error.description.contains("timed out") || error.description.contains("timeout"))
    }

    // MARK: - Session Configuration Tests

    @Test("SessionConfiguration has sensible defaults")
    func testSessionConfigurationDefaults() {
        let config = SessionConfiguration.default

        #expect(config.domain == "localhost")
        #expect(config.maxCommandLength == 512)
        #expect(config.maxMessageSize == 10 * 1024 * 1024)
        #expect(config.connectionTimeout == 300)
        #expect(config.commandTimeout == 60)
    }

    @Test("SessionConfiguration can be customized")
    func testSessionConfigurationCustom() {
        let config = SessionConfiguration(
            domain: "smtp.example.com",
            maxCommandLength: 1024,
            maxMessageSize: 5 * 1024 * 1024,
            connectionTimeout: 600,
            commandTimeout: 120
        )

        #expect(config.domain == "smtp.example.com")
        #expect(config.maxCommandLength == 1024)
        #expect(config.maxMessageSize == 5 * 1024 * 1024)
        #expect(config.connectionTimeout == 600)
        #expect(config.commandTimeout == 120)
    }

    @Test("SessionConfiguration timeout can be disabled")
    func testSessionConfigurationNoTimeout() {
        let config = SessionConfiguration(
            domain: "test.local",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        #expect(config.connectionTimeout == 0)
        #expect(config.commandTimeout == 0)
    }

    // MARK: - Resource Cleanup Tests

    @Test("Server cleans up resources on stop")
    func testServerResourceCleanup() async throws {
        let config = ServerConfiguration(
            domain: "test.local",
            port: 0,
            maxConnections: 10,
            maxMessageSize: 1024 * 1024
        )
        let server = SMTPServer(configuration: config)

        let serverTask = Task {
            try await server.start()
        }

        try await Task.sleep(for: .milliseconds(100))

        // Stop should clean up all resources
        try await server.stop()

        // Multiple stops should be safe
        try await server.stop()

        serverTask.cancel()
        // Test passes if cleanup completed without error
    }
}

// Helper extension for testing
fileprivate extension SMTPServer {
    func setMessageHandler(_ handler: @escaping @Sendable (EmailMessage) -> Void) async {
        self.messageHandler = handler
    }
}
