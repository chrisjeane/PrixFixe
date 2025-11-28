/// OpenSSL TLS Support for Linux
///
/// This module provides Swift wrappers around OpenSSL for TLS support on Linux.
/// It is conditionally compiled only on Linux platforms where OpenSSL is the
/// standard TLS library.
///
/// Architecture:
/// - OpenSSL context (SSL_CTX) manages shared TLS configuration
/// - SSL connection (SSL) represents individual TLS session state
/// - BIO layer could be used but we integrate directly with file descriptors
/// - Error handling uses OpenSSL's error queue for diagnostics

#if canImport(Glibc)

import Foundation

// Import OpenSSL C library
// On Linux, OpenSSL is typically available as a system library
#if canImport(COpenSSL)
import COpenSSL
#else
// Fallback for systems where COpenSSL module isn't available
// In this case, we'll need to manually link against -lssl -lcrypto
@_implementationOnly import Glibc

// OpenSSL function declarations
// These are minimal declarations needed for TLS support
// In production, use a proper module map or COpenSSL package

// Opaque pointer types for OpenSSL structures
typealias SSL_METHOD = OpaquePointer
typealias SSL_CTX = OpaquePointer
typealias SSL = OpaquePointer
typealias X509 = OpaquePointer
typealias EVP_PKEY = OpaquePointer
typealias BIO = OpaquePointer

// SSL/TLS versions
let TLS1_VERSION: Int32 = 0x0301
let TLS1_1_VERSION: Int32 = 0x0302
let TLS1_2_VERSION: Int32 = 0x0303
let TLS1_3_VERSION: Int32 = 0x0304

// SSL error codes
let SSL_ERROR_NONE: Int32 = 0
let SSL_ERROR_WANT_READ: Int32 = 2
let SSL_ERROR_WANT_WRITE: Int32 = 3
let SSL_ERROR_SYSCALL: Int32 = 5
let SSL_ERROR_SSL: Int32 = 6

// File types for certificate loading
let SSL_FILETYPE_PEM: Int32 = 1
let SSL_FILETYPE_ASN1: Int32 = 2

// OpenSSL initialization and cleanup
@_silgen_name("OPENSSL_init_ssl")
func OPENSSL_init_ssl(_ opts: UInt64, _ settings: OpaquePointer?) -> Int32

@_silgen_name("OPENSSL_init_crypto")
func OPENSSL_init_crypto(_ opts: UInt64, _ settings: OpaquePointer?) -> Int32

// SSL context management
@_silgen_name("TLS_server_method")
func TLS_server_method() -> SSL_METHOD?

@_silgen_name("SSL_CTX_new")
func SSL_CTX_new(_ method: SSL_METHOD?) -> SSL_CTX?

@_silgen_name("SSL_CTX_free")
func SSL_CTX_free(_ ctx: SSL_CTX?)

@_silgen_name("SSL_CTX_set_min_proto_version")
func SSL_CTX_set_min_proto_version(_ ctx: SSL_CTX?, _ version: Int32) -> Int32

@_silgen_name("SSL_CTX_use_certificate_file")
func SSL_CTX_use_certificate_file(_ ctx: SSL_CTX?, _ file: UnsafePointer<CChar>?, _ type: Int32) -> Int32

@_silgen_name("SSL_CTX_use_PrivateKey_file")
func SSL_CTX_use_PrivateKey_file(_ ctx: SSL_CTX?, _ file: UnsafePointer<CChar>?, _ type: Int32) -> Int32

@_silgen_name("SSL_CTX_check_private_key")
func SSL_CTX_check_private_key(_ ctx: SSL_CTX?) -> Int32

@_silgen_name("SSL_CTX_use_certificate")
func SSL_CTX_use_certificate(_ ctx: SSL_CTX?, _ x: X509?) -> Int32

@_silgen_name("SSL_CTX_use_PrivateKey")
func SSL_CTX_use_PrivateKey(_ ctx: SSL_CTX?, _ pkey: EVP_PKEY?) -> Int32

// SSL connection management
@_silgen_name("SSL_new")
func SSL_new(_ ctx: SSL_CTX?) -> SSL?

@_silgen_name("SSL_free")
func SSL_free(_ ssl: SSL?)

@_silgen_name("SSL_set_fd")
func SSL_set_fd(_ ssl: SSL?, _ fd: Int32) -> Int32

@_silgen_name("SSL_accept")
func SSL_accept(_ ssl: SSL?) -> Int32

@_silgen_name("SSL_connect")
func SSL_connect(_ ssl: SSL?) -> Int32

@_silgen_name("SSL_read")
func SSL_read(_ ssl: SSL?, _ buf: UnsafeMutableRawPointer?, _ num: Int32) -> Int32

@_silgen_name("SSL_write")
func SSL_write(_ ssl: SSL?, _ buf: UnsafeRawPointer?, _ num: Int32) -> Int32

@_silgen_name("SSL_shutdown")
func SSL_shutdown(_ ssl: SSL?) -> Int32

@_silgen_name("SSL_get_error")
func SSL_get_error(_ ssl: SSL?, _ ret: Int32) -> Int32

// Certificate and key parsing from memory (BIO-based)
@_silgen_name("BIO_new_mem_buf")
func BIO_new_mem_buf(_ buf: UnsafeRawPointer?, _ len: Int32) -> BIO?

@_silgen_name("BIO_free")
func BIO_free(_ bio: BIO?) -> Int32

@_silgen_name("PEM_read_bio_X509")
func PEM_read_bio_X509(_ bio: BIO?, _ x: UnsafeMutablePointer<X509?>?, _ cb: OpaquePointer?, _ u: UnsafeMutableRawPointer?) -> X509?

@_silgen_name("PEM_read_bio_PrivateKey")
func PEM_read_bio_PrivateKey(_ bio: BIO?, _ pkey: UnsafeMutablePointer<EVP_PKEY?>?, _ cb: OpaquePointer?, _ u: UnsafeMutableRawPointer?) -> EVP_PKEY?

@_silgen_name("X509_free")
func X509_free(_ x: X509?)

@_silgen_name("EVP_PKEY_free")
func EVP_PKEY_free(_ pkey: EVP_PKEY?)

// Error handling
@_silgen_name("ERR_get_error")
func ERR_get_error() -> UInt64

@_silgen_name("ERR_error_string_n")
func ERR_error_string_n(_ err: UInt64, _ buf: UnsafeMutablePointer<CChar>?, _ len: Int)

@_silgen_name("ERR_clear_error")
func ERR_clear_error()

#endif

// MARK: - Swift Wrappers

/// OpenSSL library initialization
///
/// This must be called before any other OpenSSL functions.
/// It is idempotent - safe to call multiple times.
internal func initializeOpenSSL() {
    // Initialize OpenSSL library
    // OPENSSL_INIT_LOAD_SSL_STRINGS = 0x00200000L
    // OPENSSL_INIT_LOAD_CRYPTO_STRINGS = 0x00000002L
    let _ = OPENSSL_init_ssl(0x00200000, nil)
    let _ = OPENSSL_init_crypto(0x00000002, nil)
}

/// OpenSSL error description
///
/// Retrieves the most recent error from OpenSSL's error queue
/// and returns it as a human-readable string.
internal func getOpenSSLError() -> String {
    let error = ERR_get_error()
    guard error != 0 else {
        return "Unknown OpenSSL error"
    }

    var buffer = [CChar](repeating: 0, count: 256)
    ERR_error_string_n(error, &buffer, 256)

    return String(cString: buffer)
}

/// Clear OpenSSL error queue
internal func clearOpenSSLErrors() {
    ERR_clear_error()
}

/// OpenSSL Context Wrapper
///
/// Manages the SSL_CTX lifecycle and provides Swift-friendly APIs
/// for configuring TLS parameters.
internal final class OpenSSLContext {
    private let ctx: SSL_CTX

    init() throws {
        // Ensure OpenSSL is initialized
        initializeOpenSSL()

        // Create SSL context with TLS server method
        guard let method = TLS_server_method() else {
            throw NetworkError.tlsUpgradeFailed("Failed to get TLS server method")
        }

        guard let context = SSL_CTX_new(method) else {
            throw NetworkError.tlsUpgradeFailed("Failed to create SSL context: \(getOpenSSLError())")
        }

        self.ctx = context
    }

    deinit {
        SSL_CTX_free(ctx)
    }

    /// Set minimum TLS protocol version
    func setMinimumTLSVersion(_ version: TLSVersion) throws {
        let opensslVersion: Int32
        switch version {
        case .tls10:
            opensslVersion = TLS1_VERSION
        case .tls11:
            opensslVersion = TLS1_1_VERSION
        case .tls12:
            opensslVersion = TLS1_2_VERSION
        case .tls13:
            opensslVersion = TLS1_3_VERSION
        }

        let result = SSL_CTX_set_min_proto_version(ctx, opensslVersion)
        guard result == 1 else {
            throw NetworkError.tlsUpgradeFailed("Failed to set minimum TLS version: \(getOpenSSLError())")
        }
    }

    /// Load certificate from file
    func loadCertificateFile(_ path: String) throws {
        let result = SSL_CTX_use_certificate_file(ctx, path, SSL_FILETYPE_PEM)
        guard result == 1 else {
            throw NetworkError.invalidCertificate("Failed to load certificate file: \(getOpenSSLError())")
        }
    }

    /// Load private key from file
    func loadPrivateKeyFile(_ path: String) throws {
        let result = SSL_CTX_use_PrivateKey_file(ctx, path, SSL_FILETYPE_PEM)
        guard result == 1 else {
            throw NetworkError.invalidCertificate("Failed to load private key file: \(getOpenSSLError())")
        }
    }

    /// Load certificate from memory data
    func loadCertificateData(_ data: Data) throws {
        let cert = try data.withUnsafeBytes { bufferPtr -> X509 in
            guard let baseAddress = bufferPtr.baseAddress else {
                throw NetworkError.invalidCertificate("Invalid certificate data")
            }

            guard let bio = BIO_new_mem_buf(baseAddress, Int32(data.count)) else {
                throw NetworkError.invalidCertificate("Failed to create BIO for certificate: \(getOpenSSLError())")
            }
            defer { BIO_free(bio) }

            var certPtr: X509? = nil
            guard let cert = PEM_read_bio_X509(bio, &certPtr, nil, nil) else {
                throw NetworkError.invalidCertificate("Failed to parse certificate: \(getOpenSSLError())")
            }

            return cert
        }

        defer { X509_free(cert) }

        let result = SSL_CTX_use_certificate(ctx, cert)
        guard result == 1 else {
            throw NetworkError.invalidCertificate("Failed to use certificate: \(getOpenSSLError())")
        }
    }

    /// Load private key from memory data
    func loadPrivateKeyData(_ data: Data, password: String? = nil) throws {
        let key = try data.withUnsafeBytes { bufferPtr -> EVP_PKEY in
            guard let baseAddress = bufferPtr.baseAddress else {
                throw NetworkError.invalidCertificate("Invalid private key data")
            }

            guard let bio = BIO_new_mem_buf(baseAddress, Int32(data.count)) else {
                throw NetworkError.invalidCertificate("Failed to create BIO for private key: \(getOpenSSLError())")
            }
            defer { BIO_free(bio) }

            // Note: password callback not implemented in this version
            // For encrypted keys, you would need to provide a password callback
            var keyPtr: EVP_PKEY? = nil
            guard let key = PEM_read_bio_PrivateKey(bio, &keyPtr, nil, nil) else {
                throw NetworkError.invalidCertificate("Failed to parse private key: \(getOpenSSLError())")
            }

            return key
        }

        defer { EVP_PKEY_free(key) }

        let result = SSL_CTX_use_PrivateKey(ctx, key)
        guard result == 1 else {
            throw NetworkError.invalidCertificate("Failed to use private key: \(getOpenSSLError())")
        }
    }

    /// Verify that the private key matches the certificate
    func checkPrivateKey() throws {
        let result = SSL_CTX_check_private_key(ctx)
        guard result == 1 else {
            throw NetworkError.invalidCertificate("Private key does not match certificate: \(getOpenSSLError())")
        }
    }

    /// Create a new SSL connection from this context
    func createConnection() throws -> OpenSSLConnection {
        guard let ssl = SSL_new(ctx) else {
            throw NetworkError.tlsUpgradeFailed("Failed to create SSL connection: \(getOpenSSLError())")
        }

        return OpenSSLConnection(ssl: ssl)
    }
}

/// OpenSSL Connection Wrapper
///
/// Manages an individual SSL/TLS connection session.
/// Handles the TLS handshake, encrypted read/write, and cleanup.
internal final class OpenSSLConnection {
    private let ssl: SSL

    init(ssl: SSL) {
        self.ssl = ssl
    }

    deinit {
        // Attempt graceful shutdown
        SSL_shutdown(ssl)
        SSL_free(ssl)
    }

    /// Attach this SSL connection to a file descriptor
    func setFileDescriptor(_ fd: Int32) throws {
        let result = SSL_set_fd(ssl, fd)
        guard result == 1 else {
            throw NetworkError.tlsUpgradeFailed("Failed to set file descriptor: \(getOpenSSLError())")
        }
    }

    /// Perform TLS handshake (server side)
    func acceptHandshake() throws {
        clearOpenSSLErrors()

        let result = SSL_accept(ssl)
        if result == 1 {
            // Handshake successful
            return
        }

        // Check error
        let error = SSL_get_error(ssl, result)
        switch error {
        case SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE:
            // For blocking I/O, this shouldn't happen
            // But if it does, we could retry
            throw NetworkError.tlsHandshakeFailed("Handshake would block (unexpected for blocking socket)")
        case SSL_ERROR_SYSCALL:
            throw NetworkError.tlsHandshakeFailed("System call error during handshake: \(String(cString: strerror(errno)))")
        case SSL_ERROR_SSL:
            throw NetworkError.tlsHandshakeFailed("SSL protocol error: \(getOpenSSLError())")
        default:
            throw NetworkError.tlsHandshakeFailed("Handshake failed with error: \(error)")
        }
    }

    /// Read encrypted data
    func read(maxBytes: Int) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: maxBytes)

        let bytesRead = SSL_read(ssl, &buffer, Int32(maxBytes))

        if bytesRead > 0 {
            return Data(buffer.prefix(Int(bytesRead)))
        } else if bytesRead == 0 {
            // Connection closed
            throw NetworkError.connectionClosed
        } else {
            // Error occurred
            let error = SSL_get_error(ssl, bytesRead)
            switch error {
            case SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE:
                // For blocking I/O, this shouldn't happen
                throw NetworkError.readFailed("SSL_read would block (unexpected for blocking socket)")
            case SSL_ERROR_SYSCALL:
                if errno != 0 {
                    throw NetworkError.readFailed("System call error: \(String(cString: strerror(errno)))")
                } else {
                    // EOF
                    throw NetworkError.connectionClosed
                }
            case SSL_ERROR_SSL:
                throw NetworkError.readFailed("SSL protocol error: \(getOpenSSLError())")
            default:
                throw NetworkError.readFailed("SSL_read failed with error: \(error)")
            }
        }
    }

    /// Write encrypted data
    func write(_ data: Data) throws {
        var totalWritten = 0
        var remainingData = data

        while totalWritten < data.count {
            let bytesWritten = remainingData.withUnsafeBytes { bufferPtr in
                SSL_write(ssl, bufferPtr.baseAddress!, Int32(remainingData.count))
            }

            if bytesWritten > 0 {
                totalWritten += Int(bytesWritten)
                if totalWritten < data.count {
                    remainingData = remainingData.advanced(by: Int(bytesWritten))
                }
            } else {
                // Error occurred
                let error = SSL_get_error(ssl, bytesWritten)
                switch error {
                case SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE:
                    // For blocking I/O, this shouldn't happen
                    throw NetworkError.writeFailed("SSL_write would block (unexpected for blocking socket)")
                case SSL_ERROR_SYSCALL:
                    throw NetworkError.writeFailed("System call error: \(String(cString: strerror(errno)))")
                case SSL_ERROR_SSL:
                    throw NetworkError.writeFailed("SSL protocol error: \(getOpenSSLError())")
                default:
                    throw NetworkError.writeFailed("SSL_write failed with error: \(error)")
                }
            }
        }
    }
}

#endif // canImport(Glibc)
