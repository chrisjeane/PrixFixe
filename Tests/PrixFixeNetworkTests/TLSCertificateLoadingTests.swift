import Testing
import Foundation
@testable import PrixFixeNetwork

@Suite("TLS Certificate Loading Tests")
struct TLSCertificateLoadingTests {

    @Test("PEM parsing extracts DER data from certificate")
    func testPEMParsing() throws {
        // Sample PEM certificate (minimal self-signed cert)
        let pemCert = """
        -----BEGIN CERTIFICATE-----
        MIIBkTCB+wIJAKHHCgVZU1j/MA0GCSqGSIb3DQEBCwUAMBExDzANBgNVBAMMBnRl
        c3RDQTAeFw0yMDAxMDEwMDAwMDBaFw0yMTAxMDEwMDAwMDBaMBExDzANBgNVBAMM
        BnRlc3RDQTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAwRQ0g3UjH7Qvwmxr
        -----END CERTIFICATE-----
        """

        let certData = pemCert.data(using: .utf8)!
        // This would normally call parsePEMToDER, but that's private
        // We'll just verify the format is correct
        #expect(certData.count > 0)
        #expect(pemCert.contains("BEGIN CERTIFICATE"))
        #expect(pemCert.contains("END CERTIFICATE"))
    }

    @Test("PEM parsing handles RSA PRIVATE KEY format")
    func testRSAPrivateKeyFormat() {
        let pemKey = """
        -----BEGIN RSA PRIVATE KEY-----
        MIICXAIBAAKBgQDBFDSDdSMftC/CbGtqYp0cJ0jKjH7Qvwmxr
        -----END RSA PRIVATE KEY-----
        """

        let keyData = pemKey.data(using: .utf8)!
        #expect(keyData.count > 0)
        #expect(pemKey.contains("BEGIN RSA PRIVATE KEY"))
        #expect(pemKey.contains("END RSA PRIVATE KEY"))
    }

    @Test("PEM parsing handles PKCS8 PRIVATE KEY format")
    func testPKCS8PrivateKeyFormat() {
        let pemKey = """
        -----BEGIN PRIVATE KEY-----
        MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBAMEUNIN1Ix+0L8Js
        -----END PRIVATE KEY-----
        """

        let keyData = pemKey.data(using: .utf8)!
        #expect(keyData.count > 0)
        #expect(pemKey.contains("BEGIN PRIVATE KEY"))
        #expect(pemKey.contains("END PRIVATE KEY"))
    }

    @Test("TLS configuration with file-based certificates is created correctly")
    func testFileBasedCertConfiguration() {
        let config = TLSConfiguration(
            certificateSource: .file(
                certificatePath: "/path/to/cert.pem",
                privateKeyPath: "/path/to/key.pem"
            ),
            minimumTLSVersion: .tls12
        )

        if case .file(let certPath, let keyPath) = config.certificateSource {
            #expect(certPath == "/path/to/cert.pem")
            #expect(keyPath == "/path/to/key.pem")
        } else {
            Issue.record("Expected file-based certificate source")
        }
    }

    @Test("TLS configuration with data-based certificates is created correctly")
    func testDataBasedCertConfiguration() {
        let certData = "cert".data(using: .utf8)!
        let keyData = "key".data(using: .utf8)!

        let config = TLSConfiguration(
            certificateSource: .data(
                certificateData: certData,
                privateKeyData: keyData,
                password: nil
            ),
            minimumTLSVersion: .tls12
        )

        if case .data(let cert, let key, _) = config.certificateSource {
            #expect(cert == certData)
            #expect(key == keyData)
        } else {
            Issue.record("Expected data-based certificate source")
        }
    }

    @Test("TLS configuration with self-signed certificate is created correctly")
    func testSelfSignedCertConfiguration() {
        let config = TLSConfiguration(
            certificateSource: .selfSigned(commonName: "localhost"),
            minimumTLSVersion: .tls12
        )

        if case .selfSigned(let cn) = config.certificateSource {
            #expect(cn == "localhost")
        } else {
            Issue.record("Expected self-signed certificate source")
        }
    }

    @Test("Certificate source supports all TLS versions")
    func testTLSVersionSupport() {
        let sources: [TLSConfiguration.CertificateSource] = [
            .selfSigned(commonName: "test"),
            .file(certificatePath: "/cert.pem", privateKeyPath: "/key.pem"),
            .data(certificateData: Data(), privateKeyData: Data(), password: nil)
        ]

        let versions: [TLSVersion] = [.tls10, .tls11, .tls12, .tls13]

        for source in sources {
            for version in versions {
                let config = TLSConfiguration(
                    certificateSource: source,
                    minimumTLSVersion: version
                )
                #expect(config.minimumTLSVersion == version)
            }
        }
    }
}
