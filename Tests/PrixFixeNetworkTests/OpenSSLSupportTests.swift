/// Tests for OpenSSL TLS Support on Linux
///
/// These tests verify the OpenSSL wrapper implementation and TLS functionality
/// on Linux platforms. They are conditionally compiled only on Linux.

import Testing
import Foundation

#if canImport(Glibc)
@testable import PrixFixeNetwork

@Suite("OpenSSL Support Tests")
struct OpenSSLSupportTests {

    @Test("OpenSSL initialization does not crash")
    func testOpenSSLInitialization() throws {
        // Should not throw or crash
        initializeOpenSSL()

        // Should be idempotent - safe to call multiple times
        initializeOpenSSL()
        initializeOpenSSL()
    }

    @Test("OpenSSL context creation succeeds")
    func testContextCreation() throws {
        let context = try OpenSSLContext()

        // Context should be created successfully
        // Destructor will be called automatically when context goes out of scope
    }

    @Test("Setting minimum TLS version succeeds")
    func testSetMinimumTLSVersion() throws {
        let context = try OpenSSLContext()

        // Test all TLS versions
        try context.setMinimumTLSVersion(.tls10)
        try context.setMinimumTLSVersion(.tls11)
        try context.setMinimumTLSVersion(.tls12)
        try context.setMinimumTLSVersion(.tls13)
    }

    @Test("Loading non-existent certificate file fails")
    func testLoadInvalidCertificateFile() throws {
        let context = try OpenSSLContext()

        // Should throw when loading non-existent file
        #expect(throws: NetworkError.self) {
            try context.loadCertificateFile("/nonexistent/cert.pem")
        }
    }

    @Test("Loading non-existent private key file fails")
    func testLoadInvalidPrivateKeyFile() throws {
        let context = try OpenSSLContext()

        // Should throw when loading non-existent file
        #expect(throws: NetworkError.self) {
            try context.loadPrivateKeyFile("/nonexistent/key.pem")
        }
    }

    @Test("Loading invalid certificate data fails")
    func testLoadInvalidCertificateData() throws {
        let context = try OpenSSLContext()

        // Invalid certificate data
        let invalidData = Data("not a certificate".utf8)

        #expect(throws: NetworkError.self) {
            try context.loadCertificateData(invalidData)
        }
    }

    @Test("Loading invalid private key data fails")
    func testLoadInvalidPrivateKeyData() throws {
        let context = try OpenSSLContext()

        // Invalid private key data
        let invalidData = Data("not a private key".utf8)

        #expect(throws: NetworkError.self) {
            try context.loadPrivateKeyData(invalidData)
        }
    }

    @Test("Error handling returns descriptive messages")
    func testErrorHandling() throws {
        // Clear any existing errors
        clearOpenSSLErrors()

        // Getting error with no error should return a default message
        let errorMsg = getOpenSSLError()
        #expect(!errorMsg.isEmpty)
    }

    @Test("Creating SSL connection from context succeeds")
    func testCreateConnection() throws {
        let context = try OpenSSLContext()

        // Should be able to create a connection
        let connection = try context.createConnection()

        // Connection should be valid (destructor will clean up)
    }

    @Test("Setting file descriptor on connection with invalid FD fails gracefully")
    func testSetInvalidFileDescriptor() throws {
        let context = try OpenSSLContext()
        let connection = try context.createConnection()

        // Invalid file descriptor (-1)
        // OpenSSL should accept any FD value, but operations will fail later
        // This test just verifies it doesn't crash
        try connection.setFileDescriptor(-1)
    }
}

@Suite("OpenSSL Integration Tests")
struct OpenSSLIntegrationTests {

    @Test("TLS configuration with file source can be created")
    func testTLSConfigurationFileSource() throws {
        let config = TLSConfiguration(
            certificateSource: .file(
                certificatePath: "/tmp/test-cert.pem",
                privateKeyPath: "/tmp/test-key.pem"
            ),
            minimumTLSVersion: .tls12
        )

        #expect(config.minimumTLSVersion == .tls12)
    }

    @Test("TLS configuration with data source can be created")
    func testTLSConfigurationDataSource() throws {
        let certData = Data("test cert".utf8)
        let keyData = Data("test key".utf8)

        let config = TLSConfiguration(
            certificateSource: .data(
                certificateData: certData,
                privateKeyData: keyData,
                password: nil
            ),
            minimumTLSVersion: .tls13
        )

        #expect(config.minimumTLSVersion == .tls13)
    }
}

#endif // canImport(Glibc)
