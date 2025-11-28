/// TLS Configuration for STARTTLS Support
///
/// Provides configuration options for TLS encryption, including certificate sources,
/// protocol versions, and security settings.

import Foundation

/// TLS protocol versions
///
/// Represents the various TLS protocol versions that can be used for secure connections.
/// TLS 1.2 and higher are recommended for production use.
public enum TLSVersion: Int, Sendable {
    /// TLS 1.0 (deprecated, not recommended)
    case tls10 = 1

    /// TLS 1.1 (deprecated, not recommended)
    case tls11 = 2

    /// TLS 1.2 (minimum recommended version)
    case tls12 = 3

    /// TLS 1.3 (most secure, preferred)
    case tls13 = 4
}

/// Configuration for TLS connections
///
/// Defines how TLS should be configured for secure SMTP connections via STARTTLS.
/// Supports file-based certificates, in-memory data, and self-signed certificates
/// for development.
///
/// ## Example
///
/// ```swift
/// // File-based certificate
/// let config = TLSConfiguration(
///     certificateSource: .file(
///         certificatePath: "/etc/ssl/certs/mail.example.com.pem",
///         privateKeyPath: "/etc/ssl/private/mail.example.com.key"
///     ),
///     minimumTLSVersion: .tls12
/// )
///
/// // Self-signed certificate for development
/// let devConfig = TLSConfiguration(
///     certificateSource: .selfSigned(commonName: "localhost")
/// )
/// ```
public struct TLSConfiguration: Sendable {
    /// Source of the TLS certificate and private key
    public enum CertificateSource: Sendable {
        /// Certificate and private key loaded from files
        ///
        /// - Parameters:
        ///   - certificatePath: Path to the certificate file (PEM format)
        ///   - privateKeyPath: Path to the private key file (PEM format)
        case file(certificatePath: String, privateKeyPath: String)

        /// Certificate and private key provided as in-memory data
        ///
        /// - Parameters:
        ///   - certificateData: Certificate data (PEM or DER format)
        ///   - privateKeyData: Private key data (PEM or DER format)
        ///   - password: Optional password for encrypted private key
        case data(certificateData: Data, privateKeyData: Data, password: String?)

        /// Self-signed certificate generated at runtime
        ///
        /// - Parameter commonName: Common Name (CN) for the certificate
        /// - Warning: Only use for development and testing. Never use in production.
        case selfSigned(commonName: String)
    }

    /// Certificate and private key source
    public let certificateSource: CertificateSource

    /// Minimum TLS protocol version to accept
    ///
    /// Connections using older protocol versions will be rejected.
    /// Default is TLS 1.2, which is the minimum recommended for production.
    public let minimumTLSVersion: TLSVersion

    /// Whether to require client certificates (mutual TLS)
    ///
    /// When true, clients must present a valid certificate to complete the TLS handshake.
    /// This provides additional authentication beyond SMTP AUTH.
    ///
    /// - Note: Client certificate validation is not implemented in v0.2.0
    public let requireClientCertificate: Bool

    /// Allowed cipher suites (nil = use platform defaults)
    ///
    /// Specify explicit cipher suites to restrict or customize the available
    /// encryption algorithms. When nil, the platform will select secure defaults.
    ///
    /// - Note: Custom cipher suites are platform-specific and not portable
    public let cipherSuites: [String]?

    /// Initialize TLS configuration
    ///
    /// - Parameters:
    ///   - certificateSource: Source of the certificate and private key
    ///   - minimumTLSVersion: Minimum acceptable TLS version. Defaults to TLS 1.2.
    ///   - requireClientCertificate: Whether to require client certificates. Defaults to false.
    ///   - cipherSuites: Optional list of allowed cipher suites. Defaults to nil (platform default).
    public init(
        certificateSource: CertificateSource,
        minimumTLSVersion: TLSVersion = .tls12,
        requireClientCertificate: Bool = false,
        cipherSuites: [String]? = nil
    ) {
        self.certificateSource = certificateSource
        self.minimumTLSVersion = minimumTLSVersion
        self.requireClientCertificate = requireClientCertificate
        self.cipherSuites = cipherSuites
    }
}
