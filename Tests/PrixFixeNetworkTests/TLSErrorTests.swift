import Testing
import Foundation
@testable import PrixFixeNetwork

@Suite("TLS Error Tests")
struct TLSErrorTests {

    // MARK: - NetworkError TLS-Specific Cases

    @Test("TLS upgrade failed error")
    func testTLSUpgradeFailedError() {
        let error = NetworkError.tlsUpgradeFailed("Certificate not found")

        #expect(error.description.contains("TLS upgrade failed"))
        #expect(error.description.contains("Certificate not found"))
    }

    @Test("Invalid certificate error")
    func testInvalidCertificateError() {
        let error = NetworkError.invalidCertificate("Certificate has expired")

        #expect(error.description.contains("Invalid certificate"))
        #expect(error.description.contains("Certificate has expired"))
    }

    @Test("TLS handshake failed error")
    func testTLSHandshakeFailedError() {
        let error = NetworkError.tlsHandshakeFailed("Protocol version mismatch")

        #expect(error.description.contains("TLS handshake failed"))
        #expect(error.description.contains("Protocol version mismatch"))
    }

    @Test("TLS already active error")
    func testTLSAlreadyActiveError() {
        let error = NetworkError.tlsAlreadyActive

        #expect(error.description.contains("TLS is already active"))
    }

    // MARK: - Error Descriptions

    @Test("TLS upgrade failed error description is informative")
    func testTLSUpgradeFailedDescription() {
        let reasons = [
            "Certificate file not found",
            "Private key is encrypted",
            "Unsupported certificate format",
            "Invalid PEM encoding"
        ]

        for reason in reasons {
            let error = NetworkError.tlsUpgradeFailed(reason)
            #expect(error.description.contains(reason))
        }
    }

    @Test("Invalid certificate error description is informative")
    func testInvalidCertificateDescription() {
        let reasons = [
            "Certificate chain incomplete",
            "Certificate has expired",
            "Certificate revoked",
            "Self-signed certificate in chain"
        ]

        for reason in reasons {
            let error = NetworkError.invalidCertificate(reason)
            #expect(error.description.contains(reason))
        }
    }

    @Test("TLS handshake failed error description is informative")
    func testTLSHandshakeFailedDescription() {
        let reasons = [
            "Protocol version not supported",
            "Cipher suite mismatch",
            "Certificate verification failed",
            "Handshake timeout"
        ]

        for reason in reasons {
            let error = NetworkError.tlsHandshakeFailed(reason)
            #expect(error.description.contains(reason))
        }
    }

    // MARK: - Mock Connection Error Tests

    /// Mock connection that simulates various TLS error scenarios
    actor ErrorSimulatingConnection: NetworkConnection {
        enum ErrorScenario {
            case invalidCertificatePath
            case tlsUpgradeFails
            case handshakeFails
            case alreadyActive
        }

        private let scenario: ErrorScenario
        private var _tlsActive: Bool = false

        nonisolated var remoteAddress: any NetworkAddress {
            SocketAddress.localhost(port: 12345)
        }

        init(scenario: ErrorScenario) {
            self.scenario = scenario
        }

        func read(maxBytes: Int) async throws -> Data {
            return Data()
        }

        func write(_ data: Data) async throws {}

        func close() async throws {}

        var isTLSActive: Bool {
            get async { _tlsActive }
        }

        func startTLS(configuration: TLSConfiguration) async throws {
            switch scenario {
            case .invalidCertificatePath:
                throw NetworkError.invalidCertificate("Certificate file not found at path")

            case .tlsUpgradeFails:
                throw NetworkError.tlsUpgradeFailed("Failed to initialize TLS context")

            case .handshakeFails:
                throw NetworkError.tlsHandshakeFailed("Client disconnected during handshake")

            case .alreadyActive:
                if _tlsActive {
                    throw NetworkError.tlsAlreadyActive
                }
                _tlsActive = true
            }
        }
    }

    @Test("Invalid certificate path error scenario")
    func testInvalidCertificatePathScenario() async throws {
        let conn = ErrorSimulatingConnection(scenario: .invalidCertificatePath)

        let tlsConfig = TLSConfiguration(
            certificateSource: .file(
                certificatePath: "/nonexistent/cert.pem",
                privateKeyPath: "/nonexistent/key.pem"
            )
        )

        await #expect(throws: NetworkError.self) {
            try await conn.startTLS(configuration: tlsConfig)
        }
    }

    @Test("TLS upgrade fails scenario")
    func testTLSUpgradeFailsScenario() async throws {
        let conn = ErrorSimulatingConnection(scenario: .tlsUpgradeFails)

        let tlsConfig = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost")
        )

        await #expect(throws: NetworkError.self) {
            try await conn.startTLS(configuration: tlsConfig)
        }
    }

    @Test("TLS handshake fails scenario")
    func testTLSHandshakeFailsScenario() async throws {
        let conn = ErrorSimulatingConnection(scenario: .handshakeFails)

        let tlsConfig = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost")
        )

        await #expect(throws: NetworkError.self) {
            try await conn.startTLS(configuration: tlsConfig)
        }
    }

    @Test("TLS already active scenario")
    func testTLSAlreadyActiveScenario() async throws {
        let conn = ErrorSimulatingConnection(scenario: .alreadyActive)

        let tlsConfig = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost")
        )

        // First call should succeed
        try await conn.startTLS(configuration: tlsConfig)

        let active = await conn.isTLSActive
        #expect(active)

        // Second call should fail
        await #expect(throws: NetworkError.self) {
            try await conn.startTLS(configuration: tlsConfig)
        }
    }

    // MARK: - Certificate Loading Error Tests

    @Test("Certificate file not found error")
    func testCertificateFileNotFound() {
        let config = TLSConfiguration(
            certificateSource: .file(
                certificatePath: "/path/that/does/not/exist/cert.pem",
                privateKeyPath: "/path/that/does/not/exist/key.pem"
            )
        )

        // Configuration should be created successfully
        // Error occurs only when attempting to use it
        if case .file(let certPath, let keyPath) = config.certificateSource {
            #expect(certPath.contains("/cert.pem"))
            #expect(keyPath.contains("/key.pem"))
        } else {
            Issue.record("Expected file-based certificate source")
        }
    }

    @Test("Empty certificate data error scenario")
    func testEmptyCertificateData() {
        let config = TLSConfiguration(
            certificateSource: .data(
                certificateData: Data(),
                privateKeyData: Data(),
                password: nil
            )
        )

        // Configuration should be created but would fail when used
        if case .data(let cert, let key, _) = config.certificateSource {
            #expect(cert.isEmpty)
            #expect(key.isEmpty)
        } else {
            Issue.record("Expected data-based certificate source")
        }
    }

    // MARK: - Error Pattern Matching Tests

    @Test("Can pattern match on TLS errors")
    func testErrorPatternMatching() {
        let errors: [NetworkError] = [
            .tlsUpgradeFailed("test"),
            .invalidCertificate("test"),
            .tlsHandshakeFailed("test"),
            .tlsAlreadyActive
        ]

        for error in errors {
            switch error {
            case .tlsUpgradeFailed:
                #expect(true)
            case .invalidCertificate:
                #expect(true)
            case .tlsHandshakeFailed:
                #expect(true)
            case .tlsAlreadyActive:
                #expect(true)
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test("TLS errors are distinguishable from other network errors")
    func testTLSErrorsDistinguishable() {
        let tlsErrors: [NetworkError] = [
            .tlsUpgradeFailed("test"),
            .invalidCertificate("test"),
            .tlsHandshakeFailed("test"),
            .tlsAlreadyActive
        ]

        let otherErrors: [NetworkError] = [
            .invalidAddress("test"),
            .bindFailed("test"),
            .connectionClosed,
            .readFailed("test")
        ]

        for error in tlsErrors {
            var isTLSError = false
            switch error {
            case .tlsUpgradeFailed, .invalidCertificate, .tlsHandshakeFailed, .tlsAlreadyActive:
                isTLSError = true
            default:
                break
            }
            #expect(isTLSError, "Should be identified as TLS error")
        }

        for error in otherErrors {
            var isTLSError = false
            switch error {
            case .tlsUpgradeFailed, .invalidCertificate, .tlsHandshakeFailed, .tlsAlreadyActive:
                isTLSError = true
            default:
                break
            }
            #expect(!isTLSError, "Should not be identified as TLS error")
        }
    }

    // MARK: - Error Context Tests

    @Test("TLS errors preserve error context")
    func testErrorContextPreservation() {
        let context = "Failed to load certificate from /etc/ssl/cert.pem: Permission denied"
        let error = NetworkError.invalidCertificate(context)

        #expect(error.description.contains("Permission denied"))
        #expect(error.description.contains("/etc/ssl/cert.pem"))
    }

    @Test("TLS handshake error includes protocol details")
    func testHandshakeErrorDetails() {
        let details = "TLS 1.2 handshake failed: peer does not support TLS 1.2 or higher"
        let error = NetworkError.tlsHandshakeFailed(details)

        #expect(error.description.contains("TLS 1.2"))
        #expect(error.description.contains("peer does not support"))
    }

    // MARK: - Default Connection TLS Error

    /// Mock connection without TLS support (uses default implementation)
    struct NonTLSConnection: NetworkConnection {
        var remoteAddress: any NetworkAddress {
            SocketAddress.localhost(port: 12345)
        }

        func read(maxBytes: Int) async throws -> Data {
            return Data()
        }

        func write(_ data: Data) async throws {}

        func close() async throws {}

        // Uses default implementation that throws "not supported"
    }

    @Test("Default connection implementation throws not supported error")
    func testDefaultConnectionTLSNotSupported() async throws {
        let conn = NonTLSConnection()

        let tlsConfig = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost")
        )

        await #expect(throws: NetworkError.self) {
            try await conn.startTLS(configuration: tlsConfig)
        }
    }

    @Test("Default connection isTLSActive returns false")
    func testDefaultConnectionTLSInactive() async {
        let conn = NonTLSConnection()
        let active = await conn.isTLSActive
        #expect(!active)
    }
}
