# STARTTLS Implementation Plan for PrixFixe

**Date**: 2025-11-28
**Feature**: STARTTLS/TLS Support (RFC 3207)
**Overall Complexity**: XL (Extra Large)
**Target Version**: v0.2.0
**Status**: Planning

## Overview

This document provides a comprehensive, actionable implementation plan for adding STARTTLS support to the PrixFixe SMTP server. STARTTLS allows clients to upgrade an existing plaintext connection to use TLS encryption, providing confidentiality and integrity for SMTP communications.

### What and Why

**What**: Implement RFC 3207 STARTTLS command, enabling opportunistic TLS encryption for SMTP connections.

**Why**:
- **Security**: Protect email content and credentials from eavesdropping
- **Production Readiness**: Required for most production SMTP deployments
- **Compliance**: Industry best practice and often mandatory for email infrastructure
- **User Demand**: Marked as HIGH priority in next-phase roadmap

### Architecture Impact

STARTTLS requires changes across all layers of PrixFixe:

1. **Network Layer** (`PrixFixeNetwork`): Add TLS capability to connection abstraction
2. **Core Layer** (`PrixFixeCore`): Add STARTTLS command and state machine transitions
3. **Configuration**: Add TLS certificate and key configuration
4. **Platform Layer** (`PrixFixePlatform`): May need platform-specific TLS detection

## Success Criteria

- [ ] STARTTLS command recognized and parsed
- [ ] STARTTLS advertised in EHLO capabilities
- [ ] TLS handshake successfully upgrades plaintext connections
- [ ] Encrypted data transmission works after upgrade
- [ ] Certificate configuration is flexible (file paths, embedded data)
- [ ] Works on macOS using Security.framework
- [ ] Works on Linux using OpenSSL
- [ ] All existing tests continue to pass
- [ ] New STARTTLS tests cover success and failure scenarios
- [ ] Performance impact is minimal (<5% overhead)
- [ ] Documentation includes TLS configuration examples
- [ ] Security best practices are documented

## High-Level Technical Approach

### Platform Strategy

Given the analysis, we'll use platform-specific TLS implementations:

- **macOS/iOS**: Use **Security.framework** APIs (SecureTransport)
  - Native to platform, no external dependencies
  - Well-documented Swift APIs
  - Cannot use Network.framework (no mid-connection upgrade)

- **Linux**: Use **OpenSSL** via system libraries
  - Industry standard, widely available
  - System dependency (document in README)
  - Use Swift/C interop for OpenSSL calls

### Connection Upgrade Flow

1. Client connects over plaintext socket
2. Server sends EHLO response advertising STARTTLS
3. Client sends `STARTTLS` command
4. Server responds `220 Ready to start TLS`
5. **Clear all read buffers** (critical security requirement)
6. Wrap existing file descriptor with TLS context
7. Perform TLS handshake
8. Continue SMTP session over encrypted connection
9. Client must send EHLO again after upgrade (per RFC 3207)

### State Machine Considerations

The SMTP state machine must enforce:
- STARTTLS only valid in `greeted` state (after HELO/EHLO)
- STARTTLS cannot be used after MAIL FROM
- After successful STARTTLS, client must re-authenticate (if AUTH enabled)
- After successful STARTTLS, state resets to `initial` (requiring new EHLO)

## Task Breakdown

### Phase 1: Network Protocol Abstraction (Foundation)
**Complexity**: M (Medium)
**Estimated Effort**: 6-8 hours
**Dependencies**: None

#### Task 1.1: Extend NetworkConnection Protocol
**Complexity**: S (Small)
**File**: `Sources/PrixFixeNetwork/NetworkTransport.swift`

Add TLS upgrade capability to the connection protocol:

```swift
public protocol NetworkConnection: Sendable {
    // ... existing methods ...

    /// Upgrade this connection to use TLS encryption
    /// - Parameter configuration: TLS configuration including certificates
    /// - Throws: NetworkError if TLS upgrade fails
    func startTLS(configuration: TLSConfiguration) async throws

    /// Whether TLS is currently active on this connection
    var isTLSActive: Bool { get async }
}
```

**Acceptance Criteria**:
- [ ] Protocol compiles without breaking existing implementations
- [ ] Method signatures are clear and well-documented
- [ ] DocC comments explain TLS upgrade semantics

---

#### Task 1.2: Define TLSConfiguration Structure
**Complexity**: S (Small)
**File**: `Sources/PrixFixeNetwork/TLSConfiguration.swift` (new file)

Create a configuration structure for TLS settings:

```swift
/// Configuration for TLS connections
public struct TLSConfiguration: Sendable {
    /// TLS certificate source
    public enum CertificateSource: Sendable {
        /// Certificate from file path
        case file(certificatePath: String, privateKeyPath: String)

        /// Certificate from in-memory data
        case data(certificateData: Data, privateKeyData: Data, password: String?)

        /// Self-signed certificate (development only)
        case selfSigned(commonName: String)
    }

    /// Certificate and private key
    public let certificateSource: CertificateSource

    /// Minimum TLS version to accept
    public let minimumTLSVersion: TLSVersion

    /// Require client certificates (mTLS)
    public let requireClientCertificate: Bool

    /// Allowed cipher suites (nil = platform default)
    public let cipherSuites: [String]?

    /// Initialize TLS configuration
    public init(
        certificateSource: CertificateSource,
        minimumTLSVersion: TLSVersion = .tls12,
        requireClientCertificate: Bool = false,
        cipherSuites: [String]? = nil
    )
}

/// TLS protocol versions
public enum TLSVersion: Int, Sendable {
    case tls10 = 1
    case tls11 = 2
    case tls12 = 3
    case tls13 = 4
}
```

**Acceptance Criteria**:
- [ ] Configuration supports file-based and data-based certificates
- [ ] Self-signed certificate option available for testing
- [ ] Defaults are secure (TLS 1.2 minimum)
- [ ] All properties are Sendable-safe
- [ ] DocC documentation explains each option

---

#### Task 1.3: Add NetworkError Cases
**Complexity**: XS (Extra Small)
**File**: `Sources/PrixFixeNetwork/NetworkTransport.swift`

Add TLS-specific error cases:

```swift
public enum NetworkError: Error, CustomStringConvertible {
    // ... existing cases ...

    /// TLS upgrade failed
    case tlsUpgradeFailed(String)

    /// Invalid TLS certificate
    case invalidCertificate(String)

    /// TLS handshake failed
    case tlsHandshakeFailed(String)

    /// TLS already active on connection
    case tlsAlreadyActive
}
```

**Acceptance Criteria**:
- [ ] Error cases cover all TLS failure modes
- [ ] Error messages are descriptive
- [ ] CustomStringConvertible provides useful descriptions

---

### Phase 2: macOS TLS Implementation
**Complexity**: L (Large)
**Estimated Effort**: 12-16 hours
**Dependencies**: Phase 1

#### Task 2.1: Research Security.framework APIs
**Complexity**: S (Small)

Research and document the Security.framework approach:
- SSLContext creation and configuration
- SSLSetIOFuncs for custom I/O
- SSLHandshake for TLS negotiation
- SSLRead/SSLWrite for encrypted I/O
- Certificate/identity loading

**Deliverable**: Technical spike document in `.plan/research/`

**Acceptance Criteria**:
- [ ] All required APIs identified
- [ ] Import/header requirements documented
- [ ] Code examples for each major operation
- [ ] Limitations and gotchas noted

---

#### Task 2.2: Implement TLS Upgrade in FoundationConnection (macOS)
**Complexity**: L (Large)
**File**: `Sources/PrixFixeNetwork/FoundationSocket.swift`

Implement TLS upgrade for FoundationConnection on macOS:

```swift
#if canImport(Security)
import Security

extension FoundationConnection {
    public func startTLS(configuration: TLSConfiguration) async throws {
        try await lock.withLock {
            guard !tlsActive else {
                throw NetworkError.tlsAlreadyActive
            }

            // Create SSL context
            let context = try createSSLContext(configuration)

            // Set I/O callbacks to use file descriptor
            try configureSSLIO(context: context)

            // Load certificate identity
            try loadCertificate(context: context, configuration: configuration)

            // Perform handshake
            try await performHandshake(context: context)

            // Mark TLS as active
            self.sslContext = context
            self.tlsActive = true
        }
    }

    private func createSSLContext(_ config: TLSConfiguration) throws -> SSLContext {
        // Implementation
    }

    private func performHandshake(context: SSLContext) async throws {
        // Handshake loop handling errSSLWouldBlock
    }
}
#endif
```

**Key Implementation Details**:
- Use `SSLNewContext` to create context
- Configure with `SSLSetProtocolVersionMin/Max`
- Set I/O callbacks with `SSLSetIOFuncs`
- Load certificate identity with SecIdentityRef
- Handle async handshake properly (may require multiple calls)
- Wrap read/write operations to use SSLRead/SSLWrite after TLS active

**Acceptance Criteria**:
- [ ] TLS upgrade succeeds with valid certificate
- [ ] TLS handshake completes successfully
- [ ] Data can be read/written over TLS
- [ ] Invalid certificates are rejected
- [ ] Handshake failures are reported clearly
- [ ] No memory leaks (verify with Instruments)

---

#### Task 2.3: Wrap Read/Write for TLS (macOS)
**Complexity**: M (Medium)
**File**: `Sources/PrixFixeNetwork/FoundationSocket.swift`

Modify read/write methods to use TLS when active:

```swift
public func read(maxBytes: Int) async throws -> Data {
    if tlsActive {
        return try await readTLS(maxBytes: maxBytes)
    } else {
        return try await readPlaintext(maxBytes: maxBytes)
    }
}

private func readTLS(maxBytes: Int) async throws -> Data {
    // Use SSLRead instead of posixRead
}
```

**Acceptance Criteria**:
- [ ] Plaintext read/write unchanged
- [ ] TLS read/write uses SSLRead/SSLWrite
- [ ] Error handling works for both modes
- [ ] No performance degradation for plaintext

---

### Phase 3: Linux TLS Implementation
**Complexity**: L (Large)
**Estimated Effort**: 12-16 hours
**Dependencies**: Phase 1

#### Task 3.1: Research OpenSSL APIs
**Complexity**: S (Small)

Research OpenSSL approach for Linux:
- SSL_CTX creation and configuration
- SSL_new for SSL objects
- SSL_set_fd for file descriptor binding
- SSL_connect/SSL_accept for handshake
- SSL_read/SSL_write for I/O
- Certificate/key loading

**Deliverable**: Technical spike document in `.plan/research/`

**Acceptance Criteria**:
- [ ] All required APIs identified
- [ ] C interop approach documented
- [ ] Memory management strategy clear
- [ ] Platform detection strategy defined

---

#### Task 3.2: Create OpenSSL Wrapper Module
**Complexity**: M (Medium)
**File**: `Sources/OpenSSLWrapper/` (new module)

Create a Swift wrapper for OpenSSL C APIs:

```swift
#if canImport(Glibc)
import OpenSSL  // System module

// Swift-friendly wrapper types
public final class SSLContext {
    let context: OpaquePointer

    public init() throws {
        // Wrapper implementation
    }
}

public final class SSLConnection {
    let ssl: OpaquePointer

    public func handshake() async throws {
        // Async handshake wrapper
    }
}
#endif
```

**Acceptance Criteria**:
- [ ] Module compiles on Linux
- [ ] Memory management is automatic (deinit cleanup)
- [ ] APIs are Swift-friendly
- [ ] Error handling uses Swift errors
- [ ] Module does not compile on macOS (platform-specific)

---

#### Task 3.3: Implement TLS Upgrade in FoundationConnection (Linux)
**Complexity**: L (Large)
**File**: `Sources/PrixFixeNetwork/FoundationSocket.swift`

Implement TLS upgrade for FoundationConnection on Linux:

```swift
#if canImport(Glibc)

extension FoundationConnection {
    public func startTLS(configuration: TLSConfiguration) async throws {
        // Similar structure to macOS but using OpenSSL
    }
}
#endif
```

**Acceptance Criteria**:
- [ ] TLS upgrade succeeds with valid certificate
- [ ] Handshake completes successfully
- [ ] Read/write work over TLS
- [ ] Certificate errors handled properly
- [ ] Compiles and runs on Ubuntu 22.04

---

### Phase 4: SMTP Protocol Changes
**Complexity**: M (Medium)
**Estimated Effort**: 8-10 hours
**Dependencies**: Phase 1

#### Task 4.1: Add STARTTLS Command to Enum
**Complexity**: XS (Extra Small)
**File**: `Sources/PrixFixeCore/SMTPCommand.swift`

Add STARTTLS case to SMTPCommand enum:

```swift
public enum SMTPCommand: Sendable, Equatable {
    // ... existing cases ...

    /// STARTTLS command - Upgrade to TLS
    case startTLS
}
```

Update verb property and parser to recognize STARTTLS.

**Acceptance Criteria**:
- [ ] STARTTLS command parses correctly
- [ ] Case-insensitive matching works
- [ ] No parameters required (STARTTLS takes no args)
- [ ] Existing tests continue to pass

---

#### Task 4.2: Add STARTTLS to EHLO Capabilities
**Complexity**: S (Small)
**File**: `Sources/PrixFixeCore/SMTPStateMachine.swift`

Advertise STARTTLS in EHLO response when TLS is configured:

```swift
private mutating func processEhlo(clientDomain: String, tlsAvailable: Bool) -> SMTPCommandResult {
    // ... existing code ...

    var capabilities = [
        "SIZE 10485760",
        "8BITMIME"
    ]

    // Only advertise STARTTLS if configured and not already using TLS
    if tlsAvailable && !tlsActive {
        capabilities.insert("STARTTLS", at: 0)
    }

    return .accepted(
        response: .ehlo(domain: domain, capabilities: capabilities),
        newState: .greeted
    )
}
```

**Acceptance Criteria**:
- [ ] STARTTLS appears in capabilities when TLS configured
- [ ] STARTTLS not advertised if TLS already active
- [ ] STARTTLS not advertised if no certificate configured
- [ ] Order of capabilities follows best practices

---

#### Task 4.3: Implement processStartTLS in State Machine
**Complexity**: M (Medium)
**File**: `Sources/PrixFixeCore/SMTPStateMachine.swift`

Add STARTTLS processing to state machine:

```swift
public mutating func process(_ command: SMTPCommand) -> SMTPCommandResult {
    switch command {
    // ... existing cases ...

    case .startTLS:
        return processStartTLS()
    }
}

private mutating func processStartTLS() -> SMTPCommandResult {
    // STARTTLS only valid in greeted state
    guard state == .greeted else {
        if state == .initial {
            return .rejected(response: .badSequence("Send EHLO first"))
        }
        return .rejected(response: .badSequence("STARTTLS not allowed in current state"))
    }

    // Cannot use STARTTLS if already using TLS
    guard !tlsActive else {
        return .rejected(response: .notAvailable("TLS already active"))
    }

    // Signal that TLS upgrade should happen
    // State will reset to .initial after upgrade (requiring new EHLO)
    return .accepted(
        response: SMTPResponse(code: .serviceReady, message: "Ready to start TLS"),
        newState: .initial  // Reset to initial after TLS upgrade
    )
}
```

**Important**: The state machine needs to know if TLS is active. This requires passing TLS state or adding a field.

**Acceptance Criteria**:
- [ ] STARTTLS accepted only in greeted state
- [ ] Proper error responses for bad sequences
- [ ] State resets to initial after STARTTLS
- [ ] TLS availability checked before accepting
- [ ] Tests verify all state transitions

---

#### Task 4.4: Handle STARTTLS in SMTPSession
**Complexity**: L (Large)
**File**: `Sources/PrixFixeCore/SMTPSession.swift`

Implement STARTTLS handling in the session:

```swift
private func processCommand(_ line: String) async throws {
    let command = parser.parse(line)

    // Special handling for STARTTLS
    if case .startTLS = command {
        try await handleStartTLS()
        return
    }

    // ... existing command processing ...
}

private func handleStartTLS() async throws {
    // Validate state
    let result = stateMachine.process(.startTLS)

    guard case .accepted(let response, _) = result else {
        if case .rejected(let errorResponse) = result {
            try await sendResponse(errorResponse)
        }
        return
    }

    // Send 220 Ready to start TLS
    try await sendResponse(response)

    // CRITICAL: Clear read buffers before TLS upgrade
    // This prevents plaintext data from leaking into TLS stream
    readAheadBuffer.removeAll()

    // Get TLS configuration from session config
    guard let tlsConfig = configuration.tlsConfiguration else {
        throw SMTPError.tlsNotConfigured
    }

    // Upgrade connection to TLS
    try await connection.startTLS(configuration: tlsConfig)

    // Reset state machine (client must send EHLO again)
    stateMachine.reset()

    // TLS is now active - continue session
}
```

**Critical Security Note**: Must clear `readAheadBuffer` before TLS handshake to prevent plaintext data from being processed as encrypted data.

**Acceptance Criteria**:
- [ ] STARTTLS command triggers TLS upgrade
- [ ] Read buffer cleared before upgrade
- [ ] State machine reset after upgrade
- [ ] Connection remains open after upgrade
- [ ] Subsequent commands work over TLS
- [ ] Errors during upgrade are handled gracefully
- [ ] Connection closed on TLS failure

---

### Phase 5: Configuration Integration
**Complexity**: S (Small)
**Estimated Effort**: 3-4 hours
**Dependencies**: Phase 1

#### Task 5.1: Add TLS to ServerConfiguration
**Complexity**: S (Small)
**File**: `Sources/PrixFixeCore/SMTPServer.swift`

Add TLS configuration to ServerConfiguration:

```swift
public struct ServerConfiguration: Sendable {
    // ... existing properties ...

    /// TLS configuration (nil = TLS disabled)
    public let tlsConfiguration: TLSConfiguration?

    public init(
        domain: String = "localhost",
        port: UInt16,
        maxConnections: Int = 100,
        maxMessageSize: Int = 10 * 1024 * 1024,
        tlsConfiguration: TLSConfiguration? = nil
    ) {
        // ... existing init ...
        self.tlsConfiguration = tlsConfiguration
    }
}
```

**Acceptance Criteria**:
- [ ] TLS configuration optional (nil = disabled)
- [ ] Configuration passed to sessions
- [ ] Backward compatible with existing code

---

#### Task 5.2: Add TLS to SessionConfiguration
**Complexity**: XS (Extra Small)
**File**: `Sources/PrixFixeCore/SMTPSession.swift`

Add TLS config to SessionConfiguration:

```swift
public struct SessionConfiguration: Sendable {
    // ... existing properties ...

    /// TLS configuration
    public let tlsConfiguration: TLSConfiguration?
}
```

**Acceptance Criteria**:
- [ ] Configuration available in session
- [ ] Used for EHLO capability advertising
- [ ] Used for STARTTLS command handling

---

#### Task 5.3: Update SMTPServer to Pass TLS Config
**Complexity**: XS (Extra Small)
**File**: `Sources/PrixFixeCore/SMTPServer.swift`

Pass TLS configuration to sessions:

```swift
private func handleSession(connection: any NetworkConnection, configuration: SessionConfiguration) async {
    let sessionConfig = SessionConfiguration(
        domain: configuration.domain,
        maxCommandLength: 512,
        maxMessageSize: configuration.maxMessageSize,
        connectionTimeout: 300,
        commandTimeout: 60,
        tlsConfiguration: self.configuration.tlsConfiguration  // Pass through
    )
    // ... create and run session ...
}
```

**Acceptance Criteria**:
- [ ] TLS config flows from server to session
- [ ] Sessions can access TLS config
- [ ] Nil TLS config handled gracefully

---

### Phase 6: Testing
**Complexity**: L (Large)
**Estimated Effort**: 16-20 hours
**Dependencies**: Phases 2, 3, 4, 5

#### Task 6.1: Unit Tests for TLS Configuration
**Complexity**: S (Small)
**File**: `Tests/PrixFixeNetworkTests/TLSConfigurationTests.swift` (new)

Test TLS configuration structure:

```swift
@Test("TLS configuration with file-based certificate")
func testFileBasedCertificate() {
    let config = TLSConfiguration(
        certificateSource: .file(
            certificatePath: "/path/to/cert.pem",
            privateKeyPath: "/path/to/key.pem"
        )
    )
    #expect(config.minimumTLSVersion == .tls12)
}

@Test("TLS configuration with data-based certificate")
func testDataBasedCertificate() {
    // Test implementation
}

@Test("Self-signed certificate configuration")
func testSelfSignedCertificate() {
    // Test implementation
}
```

**Acceptance Criteria**:
- [ ] At least 8 configuration tests
- [ ] All certificate sources tested
- [ ] Default values validated
- [ ] Edge cases covered

---

#### Task 6.2: Unit Tests for STARTTLS Command
**Complexity**: S (Small)
**File**: `Tests/PrixFixeCoreTests/SMTPCommandTests.swift`

Test STARTTLS command parsing:

```swift
@Test("Parse STARTTLS command")
func testParseStartTLS() {
    let parser = SMTPCommandParser()
    let cmd = parser.parse("STARTTLS")
    #expect(cmd == .startTLS)
}

@Test("STARTTLS is case-insensitive")
func testStartTLSCaseInsensitive() {
    let parser = SMTPCommandParser()
    #expect(parser.parse("starttls") == .startTLS)
    #expect(parser.parse("StartTLS") == .startTLS)
}

@Test("STARTTLS with parameters is rejected")
func testStartTLSWithParameters() {
    // Should reject parameters
}
```

**Acceptance Criteria**:
- [ ] STARTTLS parsing works correctly
- [ ] Case insensitivity verified
- [ ] Parameters rejected appropriately
- [ ] Tests pass consistently

---

#### Task 6.3: Unit Tests for State Machine
**Complexity**: M (Medium)
**File**: `Tests/PrixFixeCoreTests/SMTPStateMachineTests.swift`

Test STARTTLS state transitions:

```swift
@Test("STARTTLS accepted in greeted state")
func testStartTLSInGreetedState() {
    var sm = SMTPStateMachine(domain: "test.local")
    _ = sm.process(.ehlo(domain: "client.local"))

    let result = sm.process(.startTLS)
    guard case .accepted(let response, let newState) = result else {
        Issue.record("Expected accepted")
        return
    }

    #expect(response.code == .serviceReady)
    #expect(newState == .initial)
}

@Test("STARTTLS rejected before EHLO")
func testStartTLSBeforeEHLO() {
    var sm = SMTPStateMachine(domain: "test.local")
    let result = sm.process(.startTLS)
    guard case .rejected = result else {
        Issue.record("Expected rejected")
        return
    }
}

@Test("STARTTLS rejected after MAIL FROM")
func testStartTLSAfterMailFrom() {
    // Test implementation
}

@Test("STARTTLS rejected when TLS already active")
func testStartTLSWhenTLSActive() {
    // Test implementation
}
```

**Acceptance Criteria**:
- [ ] At least 12 state machine tests
- [ ] All state transitions validated
- [ ] Error cases covered
- [ ] TLS state tracking verified

---

#### Task 6.4: Integration Tests with Self-Signed Certificates
**Complexity**: M (Medium)
**File**: `Tests/PrixFixeCoreTests/TLSIntegrationTests.swift` (new)

Test end-to-end TLS upgrade:

```swift
@Test("STARTTLS upgrades connection successfully")
func testStartTLSUpgrade() async throws {
    // Create server with self-signed cert
    let tlsConfig = TLSConfiguration(
        certificateSource: .selfSigned(commonName: "test.local")
    )

    let config = ServerConfiguration(
        domain: "test.local",
        port: 2525,
        tlsConfiguration: tlsConfig
    )

    let server = SMTPServer(configuration: config)

    // Start server in background
    Task { try await server.start() }

    // Connect and test STARTTLS
    // ... client implementation ...

    await server.stop()
}

@Test("STARTTLS advertised in EHLO when configured")
func testStartTLSAdvertised() async throws {
    // Test implementation
}

@Test("Data encrypted after STARTTLS")
func testEncryptionActive() async throws {
    // Verify data is encrypted (hard to test directly)
    // Could test that plaintext commands fail after TLS
}
```

**Acceptance Criteria**:
- [ ] At least 10 integration tests
- [ ] TLS upgrade verified end-to-end
- [ ] Capability advertising tested
- [ ] EHLO required after STARTTLS verified
- [ ] Tests pass on both macOS and Linux

---

#### Task 6.5: Cross-Platform Tests
**Complexity**: M (Medium)
**File**: Multiple test files

Ensure tests work on all platforms:

```swift
#if os(macOS) || os(iOS)
@Test("Security.framework TLS implementation")
func testSecurityFrameworkTLS() async throws {
    // macOS-specific tests
}
#endif

#if os(Linux)
@Test("OpenSSL TLS implementation")
func testOpenSSLTLS() async throws {
    // Linux-specific tests
}
#endif
```

**Acceptance Criteria**:
- [ ] Tests compile on all platforms
- [ ] Platform-specific tests properly isolated
- [ ] Both implementations tested equivalently
- [ ] CI runs tests on macOS and Linux

---

#### Task 6.6: Error Path Testing
**Complexity**: M (Medium)
**File**: `Tests/PrixFixeNetworkTests/TLSErrorTests.swift` (new)

Test TLS failure scenarios:

```swift
@Test("Invalid certificate rejected")
func testInvalidCertificate() async throws {
    // Test with corrupted certificate
}

@Test("TLS handshake timeout")
func testHandshakeTimeout() async throws {
    // Test handshake that never completes
}

@Test("Certificate file not found")
func testCertificateNotFound() async throws {
    let config = TLSConfiguration(
        certificateSource: .file(
            certificatePath: "/nonexistent/cert.pem",
            privateKeyPath: "/nonexistent/key.pem"
        )
    )

    // Should fail when attempting TLS upgrade
}

@Test("TLS upgrade with pending data in buffer")
func testBufferClearance() async throws {
    // Ensure read buffer is cleared before TLS
}
```

**Acceptance Criteria**:
- [ ] At least 15 error tests
- [ ] Certificate errors covered
- [ ] Handshake failures covered
- [ ] Buffer clearance verified
- [ ] All errors produce clear messages

---

#### Task 6.7: Performance Testing
**Complexity**: M (Medium)
**File**: `Tests/PrixFixeCoreTests/TLSPerformanceTests.swift` (new)

Benchmark TLS performance impact:

```swift
@Test("TLS handshake performance")
func testHandshakePerformance() async throws {
    let start = Date()

    // Perform 100 TLS handshakes
    for _ in 0..<100 {
        // Handshake
    }

    let elapsed = Date().timeIntervalSince(start)
    let avgHandshake = elapsed / 100

    // Should be under 50ms on average
    #expect(avgHandshake < 0.05)
}

@Test("TLS throughput vs plaintext")
func testTLSThroughput() async throws {
    // Compare message throughput with and without TLS
    // Should be within 5% of plaintext
}
```

**Acceptance Criteria**:
- [ ] Handshake time measured
- [ ] Throughput impact quantified
- [ ] Performance acceptable (<5% overhead)
- [ ] Benchmarks run in CI

---

### Phase 7: Documentation
**Complexity**: S (Small)
**Estimated Effort**: 6-8 hours
**Dependencies**: All previous phases

#### Task 7.1: API Documentation
**Complexity**: S (Small)
**Files**: All modified source files

Add comprehensive DocC documentation:

```swift
/// Upgrade this connection to use TLS encryption.
///
/// This method performs an opportunistic TLS upgrade on an existing plaintext connection.
/// The upgrade is typically triggered by the SMTP STARTTLS command.
///
/// ## Usage
///
/// ```swift
/// let tlsConfig = TLSConfiguration(
///     certificateSource: .file(
///         certificatePath: "/path/to/cert.pem",
///         privateKeyPath: "/path/to/key.pem"
///     )
/// )
///
/// try await connection.startTLS(configuration: tlsConfig)
/// // Connection is now encrypted
/// ```
///
/// - Parameter configuration: TLS configuration including certificate and key
/// - Throws: ``NetworkError/tlsUpgradeFailed(_:)`` if the upgrade fails
/// - Throws: ``NetworkError/invalidCertificate(_:)`` if certificate is invalid
///
/// - Important: Any buffered plaintext data must be cleared before calling this method
///   to prevent security vulnerabilities.
///
/// - Note: After a successful TLS upgrade, all subsequent read and write operations
///   will be encrypted.
public func startTLS(configuration: TLSConfiguration) async throws
```

**Acceptance Criteria**:
- [ ] All public APIs documented
- [ ] Examples provided for common use cases
- [ ] Parameters and errors explained
- [ ] Security notes included
- [ ] DocC builds without warnings

---

#### Task 7.2: Integration Guide Updates
**Complexity**: S (Small)
**File**: `INTEGRATION.md`

Add TLS configuration section:

```markdown
## Configuring TLS/STARTTLS

PrixFixe supports opportunistic TLS encryption via the STARTTLS command.

### Basic Configuration

Configure TLS using a certificate file:

```swift
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/etc/ssl/certs/mail.example.com.pem",
        privateKeyPath: "/etc/ssl/private/mail.example.com.key"
    ),
    minimumTLSVersion: .tls12
)

let config = ServerConfiguration(
    domain: "mail.example.com",
    port: 587,
    tlsConfiguration: tlsConfig
)

let server = SMTPServer(configuration: config)
```

### Self-Signed Certificates (Development)

For development, use self-signed certificates:

```swift
let tlsConfig = TLSConfiguration(
    certificateSource: .selfSigned(commonName: "localhost")
)
```

⚠️ **Warning**: Self-signed certificates should never be used in production.

### Platform Requirements

- **macOS/iOS**: Uses Security.framework (no additional dependencies)
- **Linux**: Requires OpenSSL (install: `apt-get install libssl-dev`)

### Security Best Practices

1. Use TLS 1.2 or higher (TLS 1.0/1.1 are deprecated)
2. Use strong cipher suites
3. Keep certificates up to date
4. Restrict certificate key permissions (600 or stricter)
5. Use STARTTLS on port 587 (submission) rather than implicit TLS on port 465
```

**Acceptance Criteria**:
- [ ] TLS configuration documented
- [ ] Examples for all certificate sources
- [ ] Platform requirements explained
- [ ] Security best practices included
- [ ] Common pitfalls addressed

---

#### Task 7.3: README Updates
**Complexity**: XS (Extra Small)
**File**: `README.md`

Update README to reflect TLS support:

```markdown
## Features

- ✅ **Multi-platform**: Runs on Linux, macOS, and iOS
- ✅ **STARTTLS Support**: Opportunistic TLS encryption (RFC 3207)
- ✅ **Secure by Default**: TLS 1.2+ with strong cipher suites
...

## Scope for v0.2.0

**Included:**
- STARTTLS (opportunistic TLS encryption)
- ...

**Explicitly Excluded (Future Versions):**
- SMTP AUTH (authentication) - Planned for v0.3.0
- Implicit TLS (direct SSL/TLS on port 465)
...
```

**Acceptance Criteria**:
- [ ] Features list updated
- [ ] Version scope updated
- [ ] Installation notes include OpenSSL requirement for Linux
- [ ] Accurate and concise

---

#### Task 7.4: CHANGELOG Entry
**Complexity**: XS (Extra Small)
**File**: `CHANGELOG.md`

Add entry for v0.2.0:

```markdown
## [0.2.0] - TBD

### Added
- **STARTTLS Support** (RFC 3207): Opportunistic TLS encryption for SMTP connections
  - `TLSConfiguration` for flexible certificate configuration
  - File-based, data-based, and self-signed certificate support
  - Platform-specific implementations (Security.framework on macOS, OpenSSL on Linux)
  - Comprehensive TLS integration tests
- `startTLS()` method added to `NetworkConnection` protocol
- TLS-related error cases in `NetworkError`

### Changed
- `ServerConfiguration` now accepts optional `tlsConfiguration` parameter
- EHLO capabilities now advertise STARTTLS when configured
- State machine resets to initial state after successful STARTTLS

### Security
- TLS 1.2 minimum version by default
- Buffer clearance before TLS upgrade prevents data leakage
- Certificate validation using platform APIs

### Documentation
- Added TLS configuration guide to INTEGRATION.md
- Updated README with STARTTLS feature
- Comprehensive DocC documentation for all TLS APIs
```

**Acceptance Criteria**:
- [ ] All changes documented
- [ ] Security implications noted
- [ ] Breaking changes (if any) highlighted
- [ ] Follows semantic versioning

---

## Dependencies Between Tasks

```
Phase 1 (Foundation)
├─ Task 1.1: Extend NetworkConnection Protocol
├─ Task 1.2: Define TLSConfiguration Structure
└─ Task 1.3: Add NetworkError Cases
   ├─> Phase 2 (macOS Implementation)
   │   ├─ Task 2.1: Research Security.framework
   │   ├─ Task 2.2: Implement TLS in FoundationConnection
   │   └─ Task 2.3: Wrap Read/Write for TLS
   │
   ├─> Phase 3 (Linux Implementation)
   │   ├─ Task 3.1: Research OpenSSL
   │   ├─ Task 3.2: Create OpenSSL Wrapper
   │   └─ Task 3.3: Implement TLS in FoundationConnection
   │
   └─> Phase 4 (SMTP Protocol)
       ├─ Task 4.1: Add STARTTLS to Command Enum
       ├─ Task 4.2: Add to EHLO Capabilities
       ├─ Task 4.3: Implement processStartTLS
       └─ Task 4.4: Handle STARTTLS in Session
           └─> Phase 5 (Configuration)
               ├─ Task 5.1: Add TLS to ServerConfiguration
               ├─ Task 5.2: Add TLS to SessionConfiguration
               └─ Task 5.3: Update SMTPServer to Pass Config
                   └─> Phase 6 (Testing)
                       ├─ Task 6.1: Configuration Tests
                       ├─ Task 6.2: Command Tests
                       ├─ Task 6.3: State Machine Tests
                       ├─ Task 6.4: Integration Tests
                       ├─ Task 6.5: Cross-Platform Tests
                       ├─ Task 6.6: Error Path Tests
                       └─ Task 6.7: Performance Tests
                           └─> Phase 7 (Documentation)
                               ├─ Task 7.1: API Documentation
                               ├─ Task 7.2: Integration Guide
                               ├─ Task 7.3: README Updates
                               └─ Task 7.4: CHANGELOG Entry
```

**Critical Path**: Phase 1 → Phase 2/3 (parallel) → Phase 4 → Phase 5 → Phase 6 → Phase 7

**Parallelization Opportunities**:
- Phases 2 and 3 can be developed in parallel (different platforms)
- Within Phase 6, test files can be developed in parallel
- Documentation (Phase 7) can start once APIs are stable

## Risk Factors and Mitigations

### Risk 1: Platform-Specific TLS API Complexity
**Impact**: HIGH
**Probability**: MEDIUM

**Description**: Security.framework and OpenSSL have complex APIs with subtle differences. Incorrect usage could lead to security vulnerabilities or crashes.

**Mitigation**:
- Start with comprehensive research tasks (2.1, 3.1)
- Create small proof-of-concept before full implementation
- Peer review all TLS code
- Use Instruments/Valgrind to detect memory issues
- Extensive testing with invalid inputs
- Security audit before release

---

### Risk 2: Certificate Management Complexity
**Impact**: MEDIUM
**Probability**: HIGH

**Description**: Loading certificates, handling passwords, and managing identities is platform-specific and error-prone.

**Mitigation**:
- Support multiple certificate sources (file, data, self-signed)
- Provide clear error messages for certificate issues
- Document certificate requirements thoroughly
- Test with various certificate formats
- Provide utility to generate self-signed certs for testing

---

### Risk 3: Buffer Clearance Security Issue
**Impact**: HIGH
**Probability**: LOW

**Description**: If `readAheadBuffer` is not properly cleared before TLS upgrade, plaintext data could leak or be misinterpreted as encrypted data.

**Mitigation**:
- Explicitly document requirement in code comments
- Add security test specifically for buffer clearance
- Code review focusing on this issue
- Consider making buffer clearance automatic in `startTLS()`

---

### Risk 4: Performance Regression
**Impact**: MEDIUM
**Probability**: MEDIUM

**Description**: TLS encryption/decryption adds CPU overhead. Poor implementation could significantly impact throughput.

**Mitigation**:
- Benchmark plaintext vs TLS performance early
- Use platform-optimized crypto (hardware acceleration)
- Performance tests in Phase 6
- Accept up to 5% overhead as acceptable
- Profile hot paths with Instruments

---

### Risk 5: Cross-Platform Behavior Differences
**Impact**: MEDIUM
**Probability**: MEDIUM

**Description**: Security.framework and OpenSSL may behave differently in edge cases.

**Mitigation**:
- Comprehensive cross-platform testing (Task 6.5)
- Run full test suite on both macOS and Linux in CI
- Document platform-specific behaviors
- Abstract platform differences in wrapper layer
- Test on multiple OS versions

---

### Risk 6: TLS Handshake Blocking
**Impact**: MEDIUM
**Probability**: MEDIUM

**Description**: TLS handshake is potentially blocking and could exhaust thread pool in async context.

**Mitigation**:
- Use async-friendly handshake approach
- Handle errSSLWouldBlock / SSL_ERROR_WANT_READ properly
- Implement handshake timeout
- Test with slow/unresponsive clients
- Consider using detached tasks for handshake

---

### Risk 7: OpenSSL Dependency on Linux
**Impact**: LOW
**Probability**: HIGH

**Description**: Linux implementation requires OpenSSL system library, which may not be available or may be wrong version.

**Mitigation**:
- Document OpenSSL requirement clearly in README
- Provide installation instructions for common distros
- Test on Ubuntu 22.04 LTS (reference platform)
- Consider runtime check with helpful error message
- Document minimum OpenSSL version required

---

## Testing Strategy

### Unit Test Coverage Targets
- **TLSConfiguration**: 100% coverage (simple structure)
- **STARTTLS command parsing**: 100% coverage
- **State machine transitions**: 100% coverage
- **Error handling**: 95%+ coverage
- **Overall module**: 90%+ coverage

### Integration Test Priorities
1. **Happy path**: Client connects, sends STARTTLS, upgrades successfully
2. **EHLO advertising**: STARTTLS appears in capabilities when configured
3. **State reset**: Client must EHLO again after STARTTLS
4. **Buffer clearance**: No plaintext leakage after upgrade
5. **Certificate validation**: Invalid certs rejected

### Performance Benchmarks
- **TLS handshake time**: < 50ms average
- **Encrypted throughput**: Within 5% of plaintext
- **Memory overhead**: < 10% increase
- **CPU overhead**: < 5% increase

### Security Testing
- **Certificate validation**: Invalid/expired certs rejected
- **Protocol version enforcement**: TLS 1.0/1.1 rejected when configured
- **Cipher suite selection**: Weak ciphers rejected
- **Buffer clearance**: Verified with security test
- **Error message safety**: No sensitive data in error messages

## Open Questions

1. **Implicit TLS (Port 465)**: Should we support implicit TLS in addition to STARTTLS?
   - **Recommendation**: Defer to v0.3.0, focus on STARTTLS (port 587) first

2. **Client Certificate Validation (mTLS)**: Should initial implementation support client certs?
   - **Recommendation**: Include in TLSConfiguration but mark as "future enhancement"

3. **Certificate Reloading**: Should running server support certificate reload without restart?
   - **Recommendation**: Defer to v0.3.0, document requirement to restart for now

4. **Custom Cipher Suites**: Should we allow cipher suite configuration?
   - **Recommendation**: Yes, include in TLSConfiguration with nil = platform default

5. **TLS Session Resumption**: Should we support session tickets/resumption?
   - **Recommendation**: Let platform handle it, don't expose in API for v0.2.0

6. **OCSP Stapling**: Should we support OCSP stapling for certificate validation?
   - **Recommendation**: Defer to v0.4.0, low priority

## Implementation Timeline

Assuming a single developer working full-time:

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Foundation | 1 week | 1 week |
| Phase 2: macOS Implementation | 2 weeks | 3 weeks |
| Phase 3: Linux Implementation | 2 weeks | 5 weeks |
| Phase 4: SMTP Protocol | 1.5 weeks | 6.5 weeks |
| Phase 5: Configuration | 0.5 weeks | 7 weeks |
| Phase 6: Testing | 2.5 weeks | 9.5 weeks |
| Phase 7: Documentation | 1 week | 10.5 weeks |
| **Buffer/Review** | 1.5 weeks | **12 weeks** |

**Total Estimated Duration**: 12 weeks (3 months) for single developer

**Parallel Development** (2 developers):
- Developer 1: Phases 1, 2, 4, 5, 6, 7
- Developer 2: Phase 3 (can work in parallel with Phase 2)
- **Reduced Duration**: ~8-9 weeks with two developers

## Success Metrics

### Functional Metrics
- [ ] All acceptance criteria met
- [ ] 100% of tests passing on macOS and Linux
- [ ] Zero security vulnerabilities detected
- [ ] STARTTLS works with major SMTP clients (tested manually)

### Performance Metrics
- [ ] TLS handshake < 50ms average
- [ ] Throughput within 5% of plaintext
- [ ] Memory overhead < 10%
- [ ] 1000+ concurrent TLS connections supported

### Code Quality Metrics
- [ ] Zero compiler warnings
- [ ] 90%+ test coverage
- [ ] All public APIs documented
- [ ] Code review completed and approved

### Documentation Metrics
- [ ] Integration guide includes TLS examples
- [ ] README updated
- [ ] CHANGELOG complete
- [ ] Security best practices documented

## Next Steps

1. **Review and Approve Plan**: Stakeholder review of this document
2. **Set Up Development Environment**: Ensure OpenSSL available on Linux test env
3. **Create GitHub Issue**: Track STARTTLS implementation
4. **Start Phase 1**: Begin with protocol abstractions
5. **Regular Progress Updates**: Weekly status updates

## Related Documents

- [Next Phase Issues](.plan/NEXT_PHASE_ISSUES.md) - Lists STARTTLS as Feature 3
- [Implementation Roadmap](.plan/roadmaps/2025-11-27-implementation-roadmap.md) - Overall project roadmap
- RFC 3207: SMTP Service Extension for Secure SMTP over Transport Layer Security
- [Architecture Overview](.plan/architecture/2025-11-27-system-architecture.md)

---

**Document Status**: READY FOR REVIEW
**Created**: 2025-11-28
**Author**: Technical Project Planner
**Estimated Total Effort**: 52-68 hours (XL complexity)
**Target Version**: v0.2.0
