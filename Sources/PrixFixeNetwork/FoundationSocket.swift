/// BSD Socket implementation using POSIX sockets
///
/// This implementation uses low-level POSIX socket APIs to provide
/// IPv6-first networking with IPv4-mapped address support.

import Foundation

#if canImport(Darwin)
import Darwin
import Security
private let posixClose = Darwin.close
private let posixRead = Darwin.read
private let posixWrite = Darwin.write
private let posixBind = Darwin.bind
private let posixListen = Darwin.listen
private let posixAccept = Darwin.accept
// Socket type constants
private let PLATFORM_SOCK_STREAM = SOCK_STREAM
private let PLATFORM_IPPROTO_TCP = IPPROTO_TCP
private let PLATFORM_IPPROTO_IPV6 = IPPROTO_IPV6
#elseif canImport(Glibc)
import Glibc
private let posixClose = Glibc.close
private let posixRead = Glibc.read
private let posixWrite = Glibc.write
private let posixBind = Glibc.bind
private let posixListen = Glibc.listen
private let posixAccept = Glibc.accept
// Socket type constants - Linux uses different types that need Int32 conversion
private let PLATFORM_SOCK_STREAM = Int32(SOCK_STREAM.rawValue)
private let PLATFORM_IPPROTO_TCP = Int32(IPPROTO_TCP)
private let PLATFORM_IPPROTO_IPV6 = Int32(IPPROTO_IPV6)
#else
#error("Unsupported platform - requires Darwin or Glibc")
#endif

/// Socket implementation using Foundation/POSIX sockets
public final class FoundationSocket: NetworkTransport, @unchecked Sendable {
    public typealias Address = SocketAddress

    private var fileDescriptor: Int32?
    private let lock = NSLock()

    public init() {
        self.fileDescriptor = nil
    }

    deinit {
        // Synchronous cleanup in deinit
        lock.withLock {
            if let fd = fileDescriptor {
                posixClose(fd)
                fileDescriptor = nil
            }
        }
    }

    // MARK: - NetworkTransport Implementation

    public func bind(to address: SocketAddress) async throws {
        try lock.withLock {
            // Create IPv6 socket
            let fd = socket(AF_INET6, PLATFORM_SOCK_STREAM, PLATFORM_IPPROTO_TCP)
            guard fd >= 0 else {
                throw NetworkError.bindFailed("Failed to create socket: \(String(cString: strerror(errno)))")
            }

            self.fileDescriptor = fd

            // Set socket options
            try setSocketOptions(fd)

            // Bind to address
            try bindSocket(fd, to: address)
        }
    }

    public func listen(backlog: Int) async throws {
        guard let fd = fileDescriptor else {
            throw NetworkError.invalidState("Socket not bound")
        }

        let result = posixListen(fd, Int32(backlog))
        guard result == 0 else {
            throw NetworkError.listenFailed("listen() failed: \(String(cString: strerror(errno)))")
        }
    }

    public func accept() async throws -> any NetworkConnection {
        guard let fd = fileDescriptor else {
            throw NetworkError.invalidState("Socket not listening")
        }

        // Use detached task to avoid blocking cooperative thread pool
        // The blocking accept() call runs on a thread pool managed by the global concurrent executor
        return try await Task.detached {
            var addr = sockaddr_in6()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in6>.size)

            let clientFD = withUnsafeMutablePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    posixAccept(fd, sockaddrPtr, &addrLen)
                }
            }

            guard clientFD >= 0 else {
                throw NetworkError.acceptFailed("accept() failed: \(String(cString: strerror(errno)))")
            }

            // Parse remote address
            let remoteAddress = self.parseSocketAddress(from: addr)

            return FoundationConnection(fileDescriptor: clientFD, remoteAddress: remoteAddress)
        }.value
    }

    public func close() async throws {
        lock.withLock {
            guard let fd = fileDescriptor else { return }

            posixClose(fd)
            fileDescriptor = nil
        }
    }

    // MARK: - Private Helpers

    private func setSocketOptions(_ fd: Int32) throws {
        // Allow address reuse
        var reuseAddr: Int32 = 1
        let reuseResult = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        guard reuseResult == 0 else {
            throw NetworkError.bindFailed("Failed to set SO_REUSEADDR: \(String(cString: strerror(errno)))")
        }

        // Allow dual-stack (IPv6 socket can accept IPv4-mapped connections)
        var ipv6Only: Int32 = 0
        let ipv6Result = setsockopt(fd, PLATFORM_IPPROTO_IPV6, IPV6_V6ONLY, &ipv6Only, socklen_t(MemoryLayout<Int32>.size))
        guard ipv6Result == 0 else {
            throw NetworkError.bindFailed("Failed to set IPV6_V6ONLY: \(String(cString: strerror(errno)))")
        }

        // Note: Using blocking I/O with detached tasks for simplicity
        // This works well for embedded SMTP servers with moderate connection counts
        // Non-blocking I/O would be more efficient for high-volume servers but adds complexity
    }

    private func bindSocket(_ fd: Int32, to address: SocketAddress) throws {
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = address.port.bigEndian

        // Parse IPv6 address into sin6_addr
        let parseResult = inet_pton(AF_INET6, address.host, &addr.sin6_addr)
        guard parseResult == 1 else {
            throw NetworkError.bindFailed("Invalid IPv6 address: \(address.host)")
        }

        // Handle zone ID for link-local addresses
        // if_nametoindex is POSIX-standard and available on both Darwin and Glibc
        if let zoneID = address.zoneID {
            addr.sin6_scope_id = if_nametoindex(zoneID)
        }

        // Bind
        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                posixBind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }

        guard bindResult == 0 else {
            throw NetworkError.bindFailed("bind() failed: \(String(cString: strerror(errno)))")
        }
    }

    private func parseSocketAddress(from addr: sockaddr_in6) -> SocketAddress {
        var addr = addr
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))

        inet_ntop(AF_INET6, &addr.sin6_addr, &buffer, socklen_t(INET6_ADDRSTRLEN))

        // Convert CChar (Int8) to UInt8 for String decoding
        let nullTerminatorIndex = buffer.firstIndex(of: 0) ?? buffer.count
        let bytes = buffer[..<nullTerminatorIndex].map { UInt8(bitPattern: $0) }
        let host = String(decoding: bytes, as: UTF8.self)
        let port = UInt16(bigEndian: addr.sin6_port)

        // Best effort - if parsing fails, return a placeholder
        return (try? SocketAddress.ipv6(host, port: port)) ?? .localhost(port: port)
    }
}

/// Connection implementation using BSD sockets
public final class FoundationConnection: NetworkConnection, @unchecked Sendable {
    private var fileDescriptor: Int32?
    private let lock = NSLock()
    public let remoteAddress: any NetworkAddress

    // TLS state
    private var tlsActive: Bool = false

    #if canImport(Darwin)
    private var sslContext: SSLContext?
    #elseif canImport(Glibc)
    // OpenSSL state
    private var opensslContext: OpenSSLContext?
    private var opensslConnection: OpenSSLConnection?
    #endif

    init(fileDescriptor: Int32, remoteAddress: any NetworkAddress) {
        self.fileDescriptor = fileDescriptor
        self.remoteAddress = remoteAddress
    }

    deinit {
        // Synchronous cleanup in deinit
        lock.withLock {
            #if canImport(Darwin)
            if let context = sslContext {
                SSLClose(context)
            }
            #elseif canImport(Glibc)
            // OpenSSL cleanup happens automatically in deinit of wrappers
            opensslConnection = nil
            opensslContext = nil
            #endif

            if let fd = fileDescriptor {
                posixClose(fd)
                fileDescriptor = nil
            }
        }
    }

    public func read(maxBytes: Int) async throws -> Data {
        let (fd, tls) = lock.withLock { (fileDescriptor, tlsActive) }

        guard let fd = fd else {
            throw NetworkError.connectionClosed
        }

        // Use TLS read if active
        if tls {
            return try await readTLS(maxBytes: maxBytes)
        }

        // Use detached task to avoid blocking cooperative thread pool
        // The blocking read() call runs on a thread pool managed by the global concurrent executor
        return try await Task.detached {
            var buffer = [UInt8](repeating: 0, count: maxBytes)
            let bytesRead = posixRead(fd, &buffer, maxBytes)

            if bytesRead < 0 {
                let err = errno
                throw NetworkError.readFailed("read() failed: \(String(cString: strerror(err)))")
            } else if bytesRead == 0 {
                // Connection closed
                throw NetworkError.connectionClosed
            } else {
                return Data(buffer.prefix(bytesRead))
            }
        }.value
    }

    public func write(_ data: Data) async throws {
        let (fd, tls) = lock.withLock { (fileDescriptor, tlsActive) }

        guard let fd = fd else {
            throw NetworkError.connectionClosed
        }

        // Use TLS write if active
        if tls {
            return try await writeTLS(data: data)
        }

        // Use detached task to avoid blocking cooperative thread pool
        // Handles partial writes by looping until all data is sent
        try await Task.detached {
            var remainingData = data
            var totalWritten = 0

            while totalWritten < data.count {
                let bytesWritten = remainingData.withUnsafeBytes { bufferPtr in
                    posixWrite(fd, bufferPtr.baseAddress!, remainingData.count)
                }

                if bytesWritten < 0 {
                    let err = errno
                    throw NetworkError.writeFailed("write() failed: \(String(cString: strerror(err)))")
                } else if bytesWritten == 0 {
                    // No bytes written - socket may be closed
                    throw NetworkError.writeFailed("write() returned 0 bytes")
                } else {
                    // Successfully wrote some bytes
                    totalWritten += bytesWritten
                    if totalWritten < data.count {
                        // Partial write - continue with remaining data
                        remainingData = remainingData.advanced(by: bytesWritten)
                    }
                }
            }
        }.value
    }

    public func close() async throws {
        lock.withLock {
            guard let fd = fileDescriptor else { return }

            posixClose(fd)
            fileDescriptor = nil
        }
    }

    // MARK: - TLS Support

    public var isTLSActive: Bool {
        get async {
            lock.withLock { tlsActive }
        }
    }

    public func startTLS(configuration: TLSConfiguration) async throws {
        try await lock.withLock {
            guard !tlsActive else {
                throw NetworkError.tlsAlreadyActive
            }

            guard let fd = fileDescriptor else {
                throw NetworkError.invalidState("Connection closed")
            }

            #if canImport(Darwin)
            try startTLS_Darwin(configuration: configuration, fileDescriptor: fd)
            #elseif canImport(Glibc)
            try startTLS_Linux(configuration: configuration, fileDescriptor: fd)
            #else
            throw NetworkError.tlsUpgradeFailed("Platform not supported")
            #endif

            tlsActive = true
        }
    }

    // MARK: - Platform-Specific TLS Implementation

    #if canImport(Darwin)

    private func startTLS_Darwin(configuration: TLSConfiguration, fileDescriptor fd: Int32) throws {
        // Create SSL context
        guard let context = SSLCreateContext(nil, .serverSide, .streamType) else {
            throw NetworkError.tlsUpgradeFailed("Failed to create SSL context")
        }

        // Set minimum protocol version
        let minVersion: SSLProtocol
        switch configuration.minimumTLSVersion {
        case .tls10:
            minVersion = .tlsProtocol1
        case .tls11:
            minVersion = .tlsProtocol11
        case .tls12:
            minVersion = .tlsProtocol12
        case .tls13:
            minVersion = .tlsProtocol13
        }

        var status = SSLSetProtocolVersionMin(context, minVersion)
        guard status == errSecSuccess else {
            throw NetworkError.tlsUpgradeFailed("Failed to set minimum TLS version: \(status)")
        }

        // Set I/O callbacks
        status = SSLSetIOFuncs(context, sslReadCallback, sslWriteCallback)
        guard status == errSecSuccess else {
            throw NetworkError.tlsUpgradeFailed("Failed to set I/O callbacks: \(status)")
        }

        // Set connection (file descriptor as pointer)
        let connection = UnsafeMutableRawPointer(bitPattern: Int(fd))
        status = SSLSetConnection(context, connection)
        guard status == errSecSuccess else {
            throw NetworkError.tlsUpgradeFailed("Failed to set connection: \(status)")
        }

        // Load certificate and private key
        try loadCertificate_Darwin(context: context, configuration: configuration)

        // Perform handshake (blocking)
        repeat {
            status = SSLHandshake(context)
        } while status == errSSLWouldBlock

        guard status == errSecSuccess else {
            throw NetworkError.tlsHandshakeFailed("Handshake failed with status: \(status)")
        }

        self.sslContext = context
    }

    private func loadCertificate_Darwin(context: SSLContext, configuration: TLSConfiguration) throws {
        switch configuration.certificateSource {
        case .file(let certPath, let keyPath):
            // Load certificate and key from files
            guard let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)),
                  let keyData = try? Data(contentsOf: URL(fileURLWithPath: keyPath)) else {
                throw NetworkError.invalidCertificate("Failed to load certificate or key files")
            }

            // Create identity from certificate and key
            // Note: This is a simplified implementation. Production code should use
            // SecPKCS12Import or SecIdentityCreateWithCertificate
            guard let identity = try? createIdentity_Darwin(certData: certData, keyData: keyData) else {
                throw NetworkError.invalidCertificate("Failed to create identity from certificate and key")
            }

            // Set the certificate
            let status = SSLSetCertificate(context, [identity] as CFArray)
            guard status == errSecSuccess else {
                throw NetworkError.invalidCertificate("Failed to set certificate: \(status)")
            }

        case .data(let certData, let keyData, _):
            // Load from in-memory data
            guard let identity = try? createIdentity_Darwin(certData: certData, keyData: keyData) else {
                throw NetworkError.invalidCertificate("Failed to create identity from data")
            }

            let status = SSLSetCertificate(context, [identity] as CFArray)
            guard status == errSecSuccess else {
                throw NetworkError.invalidCertificate("Failed to set certificate: \(status)")
            }

        case .selfSigned(let commonName):
            // Generate a self-signed certificate
            let identity = try generateSelfSignedIdentity_Darwin(commonName: commonName)

            let status = SSLSetCertificate(context, [identity] as CFArray)
            guard status == errSecSuccess else {
                throw NetworkError.invalidCertificate("Failed to set self-signed certificate: \(status)")
            }
        }
    }

    private func createIdentity_Darwin(certData: Data, keyData: Data) throws -> SecIdentity {
        // Parse PEM-encoded certificate and key data
        let certDER = try parsePEMToDER(data: certData, label: "CERTIFICATE")
        let keyDER = try parsePEMToDER(data: keyData, label: ["PRIVATE KEY", "RSA PRIVATE KEY", "EC PRIVATE KEY"])

        // Create SecCertificate from DER data
        guard let certificate = SecCertificateCreateWithData(nil, certDER as CFData) else {
            throw NetworkError.invalidCertificate("Failed to create SecCertificate from DER data")
        }

        // Create SecKey from DER data
        let keyAttributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,  // Try RSA first, fall back to EC if needed
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrCanSign: true,
            kSecAttrCanDecrypt: true
        ]

        var error: Unmanaged<CFError>?
        let privateKey: SecKey

        if let rsaKey = SecKeyCreateWithData(keyDER as CFData, keyAttributes as CFDictionary, &error) {
            privateKey = rsaKey
        } else {
            // Try EC key if RSA fails
            let ecKeyAttributes: [CFString: Any] = [
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrCanSign: true,
                kSecAttrCanDecrypt: true
            ]

            error = nil
            guard let ecKey = SecKeyCreateWithData(keyDER as CFData, ecKeyAttributes as CFDictionary, &error) else {
                let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
                throw NetworkError.invalidCertificate("Failed to create SecKey: \(errorDesc)")
            }
            privateKey = ecKey
        }

        // Import certificate and key to temporary keychain to create identity
        // Use a unique tag based on timestamp to avoid conflicts
        let tag = "com.prixfixe.temp.\(Date().timeIntervalSince1970)".data(using: .utf8)!

        // Add certificate to keychain
        let certAddQuery: [CFString: Any] = [
            kSecClass: kSecClassCertificate,
            kSecValueRef: certificate,
            kSecAttrLabel: tag
        ]

        var certStatus = SecItemAdd(certAddQuery as CFDictionary, nil)
        if certStatus == errSecDuplicateItem {
            // Delete and retry
            SecItemDelete(certAddQuery as CFDictionary)
            certStatus = SecItemAdd(certAddQuery as CFDictionary, nil)
        }
        guard certStatus == errSecSuccess else {
            throw NetworkError.invalidCertificate("Failed to add certificate to keychain: \(certStatus)")
        }

        // Add private key to keychain
        let keyAddQuery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecValueRef: privateKey,
            kSecAttrLabel: tag,
            kSecAttrApplicationTag: tag
        ]

        var keyStatus = SecItemAdd(keyAddQuery as CFDictionary, nil)
        if keyStatus == errSecDuplicateItem {
            // Delete and retry
            SecItemDelete(keyAddQuery as CFDictionary)
            keyStatus = SecItemAdd(keyAddQuery as CFDictionary, nil)
        }
        guard keyStatus == errSecSuccess else {
            // Clean up certificate
            SecItemDelete(certAddQuery as CFDictionary)
            throw NetworkError.invalidCertificate("Failed to add private key to keychain: \(keyStatus)")
        }

        // Retrieve identity from keychain
        let identityQuery: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecAttrLabel: tag,
            kSecReturnRef: true
        ]

        var identityRef: CFTypeRef?
        let identityStatus = SecItemCopyMatching(identityQuery as CFDictionary, &identityRef)

        // Clean up temporary keychain items
        defer {
            SecItemDelete(certAddQuery as CFDictionary)
            SecItemDelete(keyAddQuery as CFDictionary)
        }

        guard identityStatus == errSecSuccess, let identity = identityRef else {
            throw NetworkError.invalidCertificate("Failed to retrieve identity from keychain: \(identityStatus)")
        }

        return (identity as! SecIdentity)
    }

    private func parsePEMToDER(data: Data, label: String) throws -> Data {
        return try parsePEMToDER(data: data, label: [label])
    }

    private func parsePEMToDER(data: Data, label: [String]) throws -> Data {
        guard let pemString = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidCertificate("PEM data is not valid UTF-8")
        }

        // Try each label variant
        for currentLabel in label {
            let beginMarker = "-----BEGIN \(currentLabel)-----"
            let endMarker = "-----END \(currentLabel)-----"

            guard let beginRange = pemString.range(of: beginMarker),
                  let endRange = pemString.range(of: endMarker) else {
                continue  // Try next label
            }

            // Extract base64 content between markers
            let base64Start = beginRange.upperBound
            let base64End = endRange.lowerBound
            let base64String = String(pemString[base64Start..<base64End])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: " ", with: "")

            guard let derData = Data(base64Encoded: base64String) else {
                throw NetworkError.invalidCertificate("Failed to decode base64 PEM content")
            }

            return derData
        }

        throw NetworkError.invalidCertificate("No valid PEM marker found. Expected one of: \(label.joined(separator: ", "))")
    }

    private func generateSelfSignedIdentity_Darwin(commonName: String) throws -> SecIdentity {
        // Generate RSA key pair
        let keyAttributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyAttributes as CFDictionary, &error) else {
            let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw NetworkError.tlsUpgradeFailed("Failed to generate private key: \(errorDesc)")
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NetworkError.tlsUpgradeFailed("Failed to extract public key")
        }

        // Create self-signed certificate
        // Note: This is a simplified implementation using the private API approach
        // For production, consider using OpenSSL or external certificate generation
        let certificate = try createSelfSignedCertificate_Darwin(
            publicKey: publicKey,
            privateKey: privateKey,
            commonName: commonName
        )

        // Import to temporary keychain
        let tag = "com.prixfixe.selfsigned.\(Date().timeIntervalSince1970)".data(using: .utf8)!

        // Add certificate
        let certAddQuery: [CFString: Any] = [
            kSecClass: kSecClassCertificate,
            kSecValueRef: certificate,
            kSecAttrLabel: tag
        ]

        var certStatus = SecItemAdd(certAddQuery as CFDictionary, nil)
        if certStatus == errSecDuplicateItem {
            SecItemDelete(certAddQuery as CFDictionary)
            certStatus = SecItemAdd(certAddQuery as CFDictionary, nil)
        }
        guard certStatus == errSecSuccess else {
            throw NetworkError.tlsUpgradeFailed("Failed to add self-signed certificate to keychain: \(certStatus)")
        }

        // Add private key
        let keyAddQuery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecValueRef: privateKey,
            kSecAttrLabel: tag,
            kSecAttrApplicationTag: tag
        ]

        var keyStatus = SecItemAdd(keyAddQuery as CFDictionary, nil)
        if keyStatus == errSecDuplicateItem {
            SecItemDelete(keyAddQuery as CFDictionary)
            keyStatus = SecItemAdd(keyAddQuery as CFDictionary, nil)
        }
        guard keyStatus == errSecSuccess else {
            SecItemDelete(certAddQuery as CFDictionary)
            throw NetworkError.tlsUpgradeFailed("Failed to add private key to keychain: \(keyStatus)")
        }

        // Retrieve identity
        let identityQuery: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecAttrLabel: tag,
            kSecReturnRef: true
        ]

        var identityRef: CFTypeRef?
        let identityStatus = SecItemCopyMatching(identityQuery as CFDictionary, &identityRef)

        // Note: We keep the keychain items for the lifetime of the identity
        // They will be cleaned up when the process exits

        guard identityStatus == errSecSuccess, let identity = identityRef else {
            SecItemDelete(certAddQuery as CFDictionary)
            SecItemDelete(keyAddQuery as CFDictionary)
            throw NetworkError.tlsUpgradeFailed("Failed to retrieve self-signed identity: \(identityStatus)")
        }

        return (identity as! SecIdentity)
    }

    private func createSelfSignedCertificate_Darwin(
        publicKey: SecKey,
        privateKey: SecKey,
        commonName: String
    ) throws -> SecCertificate {
        // Create a minimal self-signed X.509 certificate in DER format
        // This is a simplified implementation that creates a basic certificate

        // Get public key data
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw NetworkError.tlsUpgradeFailed("Failed to export public key: \(errorDesc)")
        }

        // Build a minimal X.509v3 certificate in DER format
        // This is a simplified certificate that should work for testing
        let serialNumber = UInt64.random(in: 0...UInt64.max)
        let notBefore = Date()
        let notAfter = Date(timeIntervalSinceNow: 365 * 24 * 60 * 60) // 1 year validity

        let certificateDER = try buildX509Certificate(
            serialNumber: serialNumber,
            notBefore: notBefore,
            notAfter: notAfter,
            commonName: commonName,
            publicKeyData: publicKeyData,
            privateKey: privateKey
        )

        guard let certificate = SecCertificateCreateWithData(nil, certificateDER as CFData) else {
            throw NetworkError.tlsUpgradeFailed("Failed to create SecCertificate from generated DER data")
        }

        return certificate
    }

    private func buildX509Certificate(
        serialNumber: UInt64,
        notBefore: Date,
        notAfter: Date,
        commonName: String,
        publicKeyData: Data,
        privateKey: SecKey
    ) throws -> Data {
        // This is a highly simplified X.509 certificate builder
        // For production use, consider using a proper ASN.1 library or OpenSSL

        // Build TBSCertificate (To Be Signed Certificate)
        var tbs = Data()

        // Version: v3 (2)
        tbs.append(contentsOf: [0xA0, 0x03, 0x02, 0x01, 0x02])

        // Serial Number
        let serialBytes = withUnsafeBytes(of: serialNumber.bigEndian) { Array($0) }
        tbs.append(contentsOf: [0x02, UInt8(serialBytes.count)])
        tbs.append(contentsOf: serialBytes)

        // Signature Algorithm: sha256WithRSAEncryption
        let sigAlgOID = Data([0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B])
        tbs.append(contentsOf: [0x30, UInt8(sigAlgOID.count + 2)])
        tbs.append(sigAlgOID)
        tbs.append(contentsOf: [0x05, 0x00]) // NULL

        // Issuer: CN=commonName
        let issuer = buildX509Name(commonName: commonName)
        tbs.append(issuer)

        // Validity
        let validity = buildX509Validity(notBefore: notBefore, notAfter: notAfter)
        tbs.append(validity)

        // Subject: CN=commonName (same as issuer for self-signed)
        tbs.append(issuer)

        // Subject Public Key Info
        let spki = buildX509SubjectPublicKeyInfo(publicKeyData: publicKeyData)
        tbs.append(spki)

        // Wrap TBSCertificate in SEQUENCE
        let tbsSequence = wrapInSequence(tbs)

        // Sign the TBSCertificate
        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            tbsSequence as CFData,
            &signError
        ) as Data? else {
            let errorDesc = signError?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw NetworkError.tlsUpgradeFailed("Failed to sign certificate: \(errorDesc)")
        }

        // Build final certificate: TBSCertificate + SignatureAlgorithm + Signature
        var cert = tbsSequence

        // Signature Algorithm (repeated)
        cert.append(contentsOf: [0x30, UInt8(sigAlgOID.count + 2)])
        cert.append(sigAlgOID)
        cert.append(contentsOf: [0x05, 0x00])

        // Signature (BIT STRING)
        var sigBitString = Data([0x00]) // No unused bits
        sigBitString.append(signature)
        let sigLength = encodeLength(sigBitString.count)
        cert.append(0x03) // BIT STRING tag
        cert.append(sigLength)
        cert.append(sigBitString)

        // Wrap entire certificate in SEQUENCE
        return wrapInSequence(cert)
    }

    private func buildX509Name(commonName: String) -> Data {
        // CN=commonName
        let cnOID = Data([0x06, 0x03, 0x55, 0x04, 0x03]) // id-at-commonName
        let cnValue = commonName.data(using: .utf8)!

        var attrValueSeq = Data()
        attrValueSeq.append(cnOID)
        attrValueSeq.append(0x0C) // UTF8String tag
        attrValueSeq.append(UInt8(cnValue.count))
        attrValueSeq.append(cnValue)

        let attrSeq = wrapInSequence(attrValueSeq)
        let rdnSet = wrapInSet(attrSeq)

        return wrapInSequence(rdnSet)
    }

    private func buildX509Validity(notBefore: Date, notAfter: Date) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let notBeforeStr = formatter.string(from: notBefore)
        let notAfterStr = formatter.string(from: notAfter)

        var validity = Data()

        // notBefore (UTCTime)
        let notBeforeData = notBeforeStr.data(using: .ascii)!
        validity.append(0x17) // UTCTime tag
        validity.append(UInt8(notBeforeData.count))
        validity.append(notBeforeData)

        // notAfter (UTCTime)
        let notAfterData = notAfterStr.data(using: .ascii)!
        validity.append(0x17) // UTCTime tag
        validity.append(UInt8(notAfterData.count))
        validity.append(notAfterData)

        return wrapInSequence(validity)
    }

    private func buildX509SubjectPublicKeyInfo(publicKeyData: Data) -> Data {
        // Algorithm: rsaEncryption
        let rsaOID = Data([0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01])
        var algSeq = Data()
        algSeq.append(rsaOID)
        algSeq.append(contentsOf: [0x05, 0x00]) // NULL
        let algorithm = wrapInSequence(algSeq)

        // Subject Public Key (BIT STRING)
        var pubKeyBitString = Data([0x00]) // No unused bits
        pubKeyBitString.append(publicKeyData)
        let pubKeyLength = encodeLength(pubKeyBitString.count)
        var pubKey = Data([0x03]) // BIT STRING tag
        pubKey.append(pubKeyLength)
        pubKey.append(pubKeyBitString)

        // Combine algorithm + public key
        var spki = Data()
        spki.append(algorithm)
        spki.append(pubKey)

        return wrapInSequence(spki)
    }

    private func wrapInSequence(_ data: Data) -> Data {
        var result = Data([0x30]) // SEQUENCE tag
        result.append(encodeLength(data.count))
        result.append(data)
        return result
    }

    private func wrapInSet(_ data: Data) -> Data {
        var result = Data([0x31]) // SET tag
        result.append(encodeLength(data.count))
        result.append(data)
        return result
    }

    private func encodeLength(_ length: Int) -> Data {
        if length < 128 {
            return Data([UInt8(length)])
        } else if length < 256 {
            return Data([0x81, UInt8(length)])
        } else if length < 65536 {
            let high = UInt8((length >> 8) & 0xFF)
            let low = UInt8(length & 0xFF)
            return Data([0x82, high, low])
        } else {
            // For longer lengths, use 3 bytes
            let high = UInt8((length >> 16) & 0xFF)
            let mid = UInt8((length >> 8) & 0xFF)
            let low = UInt8(length & 0xFF)
            return Data([0x83, high, mid, low])
        }
    }

    private func readTLS(maxBytes: Int) async throws -> Data {
        guard let context = lock.withLock({ sslContext }) else {
            throw NetworkError.invalidState("TLS not active")
        }

        return try await Task.detached {
            var buffer = [UInt8](repeating: 0, count: maxBytes)
            var processed: Int = 0

            let status = SSLRead(context, &buffer, maxBytes, &processed)

            if status == errSecSuccess || status == errSSLClosedGraceful {
                return Data(buffer.prefix(processed))
            } else if processed > 0 {
                // Got some data even with an error
                return Data(buffer.prefix(processed))
            } else if status == errSSLClosedAbort {
                throw NetworkError.connectionClosed
            } else {
                throw NetworkError.readFailed("TLS read failed: \(status)")
            }
        }.value
    }

    private func writeTLS(data: Data) async throws {
        guard let context = lock.withLock({ sslContext }) else {
            throw NetworkError.invalidState("TLS not active")
        }

        try await Task.detached {
            var totalWritten = 0
            var remainingData = data

            while totalWritten < data.count {
                var processed: Int = 0
                let status = remainingData.withUnsafeBytes { bufferPtr in
                    SSLWrite(context, bufferPtr.baseAddress!, remainingData.count, &processed)
                }

                if status == errSecSuccess {
                    totalWritten += processed
                    if totalWritten < data.count {
                        remainingData = remainingData.advanced(by: processed)
                    }
                } else {
                    throw NetworkError.writeFailed("TLS write failed: \(status)")
                }
            }
        }.value
    }

    #endif // canImport(Darwin)

    #if canImport(Glibc)

    private func startTLS_Linux(configuration: TLSConfiguration, fileDescriptor fd: Int32) throws {
        // Create OpenSSL context
        let context = try OpenSSLContext()

        // Set minimum TLS version
        try context.setMinimumTLSVersion(configuration.minimumTLSVersion)

        // Load certificate and private key based on source
        switch configuration.certificateSource {
        case .file(let certPath, let keyPath):
            // Load from files
            try context.loadCertificateFile(certPath)
            try context.loadPrivateKeyFile(keyPath)

        case .data(let certData, let keyData, let password):
            // Load from in-memory data
            try context.loadCertificateData(certData)
            try context.loadPrivateKeyData(keyData, password: password)

        case .selfSigned(let commonName):
            // Self-signed certificates not yet implemented
            throw NetworkError.tlsUpgradeFailed("Self-signed certificates not yet supported on Linux")
        }

        // Verify that the private key matches the certificate
        try context.checkPrivateKey()

        // Create SSL connection
        let connection = try context.createConnection()

        // Attach to file descriptor
        try connection.setFileDescriptor(fd)

        // Perform TLS handshake (server side)
        try connection.acceptHandshake()

        // Store state
        self.opensslContext = context
        self.opensslConnection = connection
    }

    private func readTLS(maxBytes: Int) async throws -> Data {
        guard let connection = lock.withLock({ opensslConnection }) else {
            throw NetworkError.invalidState("TLS not active")
        }

        // Use detached task for blocking I/O
        return try await Task.detached {
            try connection.read(maxBytes: maxBytes)
        }.value
    }

    private func writeTLS(data: Data) async throws {
        guard let connection = lock.withLock({ opensslConnection }) else {
            throw NetworkError.invalidState("TLS not active")
        }

        // Use detached task for blocking I/O
        try await Task.detached {
            try connection.write(data)
        }.value
    }

    #endif // canImport(Glibc)
}

// MARK: - SSL I/O Callbacks (Darwin)

#if canImport(Darwin)

private func sslReadCallback(
    connection: SSLConnectionRef,
    data: UnsafeMutableRawPointer,
    dataLength: UnsafeMutablePointer<Int>
) -> OSStatus {
    let fd = Int32(Int(bitPattern: connection))
    let requestedLength = dataLength.pointee

    let bytesRead = posixRead(fd, data, requestedLength)

    if bytesRead > 0 {
        dataLength.pointee = bytesRead
        return errSecSuccess
    } else if bytesRead == 0 {
        dataLength.pointee = 0
        return errSSLClosedGraceful
    } else {
        dataLength.pointee = 0
        if errno == EAGAIN || errno == EWOULDBLOCK {
            return errSSLWouldBlock
        }
        return errSSLClosedAbort
    }
}

private func sslWriteCallback(
    connection: SSLConnectionRef,
    data: UnsafeRawPointer,
    dataLength: UnsafeMutablePointer<Int>
) -> OSStatus {
    let fd = Int32(Int(bitPattern: connection))
    let requestedLength = dataLength.pointee

    let bytesWritten = posixWrite(fd, data, requestedLength)

    if bytesWritten > 0 {
        dataLength.pointee = bytesWritten
        return errSecSuccess
    } else if bytesWritten == 0 {
        dataLength.pointee = 0
        return errSSLClosedGraceful
    } else {
        dataLength.pointee = 0
        if errno == EAGAIN || errno == EWOULDBLOCK {
            return errSSLWouldBlock
        }
        return errSSLClosedAbort
    }
}

#endif
