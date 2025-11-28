import Testing
import Foundation
@testable import PrixFixeNetwork

@Suite("TLS Configuration Tests")
struct TLSConfigurationTests {

    // MARK: - Certificate Source Tests

    @Test("File-based certificate configuration")
    func testFileCertificateConfiguration() {
        let config = TLSConfiguration(
            certificateSource: .file(
                certificatePath: "/etc/ssl/certs/server.pem",
                privateKeyPath: "/etc/ssl/private/server.key"
            )
        )

        // Verify the configuration was created
        if case .file(let certPath, let keyPath) = config.certificateSource {
            #expect(certPath == "/etc/ssl/certs/server.pem")
            #expect(keyPath == "/etc/ssl/private/server.key")
        } else {
            Issue.record("Expected file-based certificate source")
        }
    }

    @Test("Data-based certificate configuration")
    func testDataCertificateConfiguration() {
        let certData = Data("cert-data".utf8)
        let keyData = Data("key-data".utf8)
        let password = "secret"

        let config = TLSConfiguration(
            certificateSource: .data(
                certificateData: certData,
                privateKeyData: keyData,
                password: password
            )
        )

        if case .data(let cert, let key, let pass) = config.certificateSource {
            #expect(cert == certData)
            #expect(key == keyData)
            #expect(pass == password)
        } else {
            Issue.record("Expected data-based certificate source")
        }
    }

    @Test("Data-based certificate configuration without password")
    func testDataCertificateNoPassword() {
        let certData = Data("cert-data".utf8)
        let keyData = Data("key-data".utf8)

        let config = TLSConfiguration(
            certificateSource: .data(
                certificateData: certData,
                privateKeyData: keyData,
                password: nil
            )
        )

        if case .data(let cert, let key, let pass) = config.certificateSource {
            #expect(cert == certData)
            #expect(key == keyData)
            #expect(pass == nil)
        } else {
            Issue.record("Expected data-based certificate source")
        }
    }

    @Test("Self-signed certificate configuration")
    func testSelfSignedCertificateConfiguration() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost")
        )

        if case .selfSigned(let cn) = config.certificateSource {
            #expect(cn == "localhost")
        } else {
            Issue.record("Expected self-signed certificate source")
        }
    }

    @Test("Self-signed certificate with domain name")
    func testSelfSignedWithDomain() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "mail.example.com")
        )

        if case .selfSigned(let cn) = config.certificateSource {
            #expect(cn == "mail.example.com")
        } else {
            Issue.record("Expected self-signed certificate source")
        }
    }

    // MARK: - TLS Version Tests

    @Test("Default TLS version is TLS 1.2")
    func testDefaultTLSVersion() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost")
        )

        #expect(config.minimumTLSVersion == .tls12)
    }

    @Test("TLS 1.0 configuration")
    func testTLS10() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            minimumTLSVersion: .tls10
        )

        #expect(config.minimumTLSVersion == .tls10)
    }

    @Test("TLS 1.1 configuration")
    func testTLS11() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            minimumTLSVersion: .tls11
        )

        #expect(config.minimumTLSVersion == .tls11)
    }

    @Test("TLS 1.2 configuration")
    func testTLS12() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            minimumTLSVersion: .tls12
        )

        #expect(config.minimumTLSVersion == .tls12)
    }

    @Test("TLS 1.3 configuration")
    func testTLS13() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            minimumTLSVersion: .tls13
        )

        #expect(config.minimumTLSVersion == .tls13)
    }

    @Test("TLS version ordering")
    func testTLSVersionOrdering() {
        #expect(TLSVersion.tls10.rawValue < TLSVersion.tls11.rawValue)
        #expect(TLSVersion.tls11.rawValue < TLSVersion.tls12.rawValue)
        #expect(TLSVersion.tls12.rawValue < TLSVersion.tls13.rawValue)
    }

    // MARK: - Client Certificate Tests

    @Test("Default does not require client certificate")
    func testDefaultNoClientCertificate() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost")
        )

        #expect(config.requireClientCertificate == false)
    }

    @Test("Require client certificate option")
    func testRequireClientCertificate() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            requireClientCertificate: true
        )

        #expect(config.requireClientCertificate == true)
    }

    @Test("Client certificate with TLS 1.3")
    func testClientCertificateWithTLS13() {
        let config = TLSConfiguration(
            certificateSource: .file(
                certificatePath: "/etc/ssl/cert.pem",
                privateKeyPath: "/etc/ssl/key.pem"
            ),
            minimumTLSVersion: .tls13,
            requireClientCertificate: true
        )

        #expect(config.minimumTLSVersion == .tls13)
        #expect(config.requireClientCertificate == true)
    }

    // MARK: - Cipher Suite Tests

    @Test("Default cipher suites are nil (platform default)")
    func testDefaultCipherSuites() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost")
        )

        #expect(config.cipherSuites == nil)
    }

    @Test("Custom cipher suites configuration")
    func testCustomCipherSuites() {
        let ciphers = [
            "TLS_AES_256_GCM_SHA384",
            "TLS_CHACHA20_POLY1305_SHA256"
        ]

        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            cipherSuites: ciphers
        )

        #expect(config.cipherSuites == ciphers)
    }

    @Test("Empty cipher suites list")
    func testEmptyCipherSuites() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            cipherSuites: []
        )

        #expect(config.cipherSuites != nil)
        #expect(config.cipherSuites?.isEmpty == true)
    }

    // MARK: - Complete Configuration Tests

    @Test("Production-ready configuration")
    func testProductionConfiguration() {
        let config = TLSConfiguration(
            certificateSource: .file(
                certificatePath: "/etc/ssl/certs/mail.example.com.pem",
                privateKeyPath: "/etc/ssl/private/mail.example.com.key"
            ),
            minimumTLSVersion: .tls12,
            requireClientCertificate: false,
            cipherSuites: nil
        )

        #expect(config.minimumTLSVersion == .tls12)
        #expect(config.requireClientCertificate == false)
        #expect(config.cipherSuites == nil)

        if case .file(let certPath, let keyPath) = config.certificateSource {
            #expect(certPath.contains("mail.example.com.pem"))
            #expect(keyPath.contains("mail.example.com.key"))
        } else {
            Issue.record("Expected file-based certificate")
        }
    }

    @Test("Development configuration with self-signed certificate")
    func testDevelopmentConfiguration() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            minimumTLSVersion: .tls12,
            requireClientCertificate: false
        )

        if case .selfSigned(let cn) = config.certificateSource {
            #expect(cn == "localhost")
        } else {
            Issue.record("Expected self-signed certificate")
        }

        #expect(config.minimumTLSVersion == .tls12)
        #expect(config.requireClientCertificate == false)
    }

    @Test("High-security configuration")
    func testHighSecurityConfiguration() {
        let config = TLSConfiguration(
            certificateSource: .file(
                certificatePath: "/etc/ssl/cert.pem",
                privateKeyPath: "/etc/ssl/key.pem"
            ),
            minimumTLSVersion: .tls13,
            requireClientCertificate: true,
            cipherSuites: [
                "TLS_AES_256_GCM_SHA384",
                "TLS_CHACHA20_POLY1305_SHA256"
            ]
        )

        #expect(config.minimumTLSVersion == .tls13)
        #expect(config.requireClientCertificate == true)
        #expect(config.cipherSuites?.count == 2)
    }
}
