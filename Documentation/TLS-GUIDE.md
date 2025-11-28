# PrixFixe TLS/STARTTLS Guide

Complete guide to configuring and using TLS encryption in PrixFixe SMTP server.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Certificate Requirements](#certificate-requirements)
- [Configuration Options](#configuration-options)
- [Platform Differences](#platform-differences)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

## Overview

PrixFixe supports STARTTLS, allowing SMTP clients to upgrade plain-text connections to encrypted TLS connections. This implementation follows RFC 3207 and provides production-ready TLS support across all platforms.

### What is STARTTLS?

STARTTLS is an SMTP extension that allows a client to upgrade an existing plain-text connection to use TLS encryption. The typical flow is:

1. Client connects to server over plain-text TCP
2. Server advertises STARTTLS capability in EHLO response
3. Client sends STARTTLS command
4. Server responds with "220 Ready to start TLS"
5. Both parties perform TLS handshake
6. Connection is now encrypted
7. Client must send EHLO again over the encrypted connection

### Platform-Native Implementations

PrixFixe uses platform-native TLS implementations for optimal security and performance:

- **macOS/iOS**: Security.framework (system-provided, no additional dependencies)
- **Linux**: OpenSSL (requires libssl-dev package)

Both implementations provide:
- TLS 1.2 and TLS 1.3 support
- Strong cipher suites by default
- Certificate validation
- Secure key handling

## Quick Start

### Basic TLS Configuration

```swift
import PrixFixe
import PrixFixeCore
import PrixFixeNetwork

// Configure TLS with certificate files
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/etc/ssl/certs/mail.example.com.pem",
        privateKeyPath: "/etc/ssl/private/mail.example.com.key"
    )
)

// Create server with TLS enabled
let config = ServerConfiguration(
    domain: "mail.example.com",
    port: 587,
    tlsConfiguration: tlsConfig
)

let server = SMTPServer(configuration: config)
try await server.start()
```

### Development with Self-Signed Certificate

For development and testing, you can use a self-signed certificate:

```swift
// Self-signed certificate for development only
let tlsConfig = TLSConfiguration(
    certificateSource: .selfSigned(commonName: "localhost")
)

let config = ServerConfiguration(
    domain: "localhost",
    port: 2525,
    tlsConfiguration: tlsConfig
)

let server = SMTPServer(configuration: config)
try await server.start()
```

**Warning**: Never use self-signed certificates in production. They provide encryption but not authentication.

## Certificate Requirements

### Certificate Format

PrixFixe supports certificates in PEM format (Base64-encoded DER with headers):

```
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAKJ...
...
-----END CERTIFICATE-----
```

Private keys should also be in PEM format:

```
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0...
...
-----END PRIVATE KEY-----
```

### Generating Certificates

#### Production Certificates

For production use, obtain certificates from a trusted Certificate Authority (CA) like:

- Let's Encrypt (free, automated)
- DigiCert
- Sectigo
- Your organization's internal CA

Example using Let's Encrypt with certbot:

```bash
# Install certbot
sudo apt-get install certbot  # Ubuntu/Debian

# Generate certificate
sudo certbot certonly --standalone -d mail.example.com

# Certificates will be in:
# /etc/letsencrypt/live/mail.example.com/fullchain.pem  (certificate)
# /etc/letsencrypt/live/mail.example.com/privkey.pem    (private key)
```

#### Development Certificates

For development, you can generate a self-signed certificate:

```bash
# Generate private key and certificate
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout localhost.key \
  -out localhost.crt \
  -days 365 \
  -subj "/CN=localhost"

# Use in PrixFixe
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "localhost.crt",
        privateKeyPath: "localhost.key"
    )
)
```

### Certificate Chain

For production certificates, ensure you provide the full certificate chain:

```bash
# Concatenate certificate and intermediate CA certificates
cat mail.example.com.crt intermediate.crt > fullchain.pem
```

Use the full chain file in your configuration:

```swift
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/etc/ssl/certs/fullchain.pem",
        privateKeyPath: "/etc/ssl/private/mail.example.com.key"
    )
)
```

## Configuration Options

### TLSConfiguration Structure

The `TLSConfiguration` struct provides comprehensive TLS settings:

```swift
public struct TLSConfiguration: Sendable {
    public init(
        certificateSource: CertificateSource,
        minimumTLSVersion: TLSVersion = .tls12,
        requireClientCertificate: Bool = false,
        cipherSuites: [String]? = nil
    )
}
```

### Certificate Sources

#### File-Based Certificates

Load certificates and private keys from files:

```swift
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/path/to/certificate.pem",
        privateKeyPath: "/path/to/privatekey.pem"
    )
)
```

Best for:
- Production deployments
- Certificates managed by external tools (e.g., certbot)
- Containerized environments with volume mounts

#### In-Memory Certificates

Provide certificate and key data directly:

```swift
let certData = Data(certificateString.utf8)
let keyData = Data(privateKeyString.utf8)

let tlsConfig = TLSConfiguration(
    certificateSource: .data(
        certificateData: certData,
        privateKeyData: keyData,
        password: nil  // Optional password for encrypted keys
    )
)
```

Best for:
- Certificates stored in databases or key management systems
- Encrypted private keys requiring password decryption
- Dynamic certificate provisioning

#### Self-Signed Certificates

Generate a self-signed certificate at runtime:

```swift
let tlsConfig = TLSConfiguration(
    certificateSource: .selfSigned(commonName: "localhost")
)
```

Best for:
- Local development
- Testing
- Internal tools

**Never use in production** - provides no authentication guarantees.

### TLS Protocol Versions

Specify the minimum acceptable TLS version:

```swift
public enum TLSVersion: Int, Sendable {
    case tls10 = 1  // Deprecated, not recommended
    case tls11 = 2  // Deprecated, not recommended
    case tls12 = 3  // Minimum recommended (default)
    case tls13 = 4  // Most secure, preferred
}
```

Examples:

```swift
// Require TLS 1.2 or higher (recommended)
let tlsConfig = TLSConfiguration(
    certificateSource: .file(...),
    minimumTLSVersion: .tls12
)

// Require TLS 1.3 only (most secure)
let tlsConfig = TLSConfiguration(
    certificateSource: .file(...),
    minimumTLSVersion: .tls13
)
```

**Recommendation**: Use `.tls12` as the minimum for broad compatibility, or `.tls13` for maximum security if all clients support it.

### Cipher Suites

By default, PrixFixe uses platform-selected secure cipher suites. You can optionally specify custom cipher suites:

```swift
let tlsConfig = TLSConfiguration(
    certificateSource: .file(...),
    minimumTLSVersion: .tls12,
    cipherSuites: [
        "TLS_AES_128_GCM_SHA256",
        "TLS_AES_256_GCM_SHA384",
        "TLS_CHACHA20_POLY1305_SHA256"
    ]
)
```

**Warning**: Custom cipher suites are platform-specific and may reduce compatibility. Only use if you have specific security requirements.

## Platform Differences

### macOS and iOS

**TLS Implementation**: Security.framework (native)

**Installation**: No additional dependencies required

**Features**:
- TLS 1.2 and 1.3 support
- System keychain integration available
- Strong default cipher suites
- Automatic certificate validation

**Deployment**:
```swift
// macOS/iOS - no special setup needed
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/path/to/cert.pem",
        privateKeyPath: "/path/to/key.pem"
    )
)
```

### Linux

**TLS Implementation**: OpenSSL

**Installation**:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install libssl-dev

# Fedora/RHEL
sudo dnf install openssl-devel

# Alpine Linux
apk add openssl-dev
```

**Package.swift Configuration**:

The PrixFixe package automatically links OpenSSL on Linux:

```swift
.target(
    name: "PrixFixeNetwork",
    dependencies: ["PrixFixePlatform"],
    linkerSettings: [
        .linkedLibrary("ssl", .when(platforms: [.linux])),
        .linkedLibrary("crypto", .when(platforms: [.linux]))
    ]
)
```

**Docker Setup**:

Include OpenSSL in your Dockerfile:

```dockerfile
FROM swift:6.0

# Install OpenSSL
RUN apt-get update && apt-get install -y \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and build your app
WORKDIR /app
COPY . .
RUN swift build -c release
```

## Security Considerations

### Buffer Security

PrixFixe implements critical security measures during TLS upgrade:

**Buffer Clearance**: When upgrading to TLS, all read-ahead buffers are cleared to prevent plaintext data from leaking into the encrypted stream:

```swift
// From SMTPSession.swift handleStartTLS()
// CRITICAL SECURITY: Clear read buffers before TLS upgrade
readAheadBuffer.removeAll()
```

This prevents:
- Plaintext command data from being interpreted as TLS data
- Data leakage from pre-TLS connection state
- Buffer confusion attacks

### State Reset

After successful TLS upgrade, the SMTP state machine resets to initial state:

```swift
// Client must send EHLO again after TLS upgrade
stateMachine.state = .initial
stateMachine.tlsActive = true
```

This ensures:
- Fresh authentication over encrypted connection
- No plaintext session state carries over
- Client must re-negotiate capabilities

Per RFC 3207 Section 4.2:
> The client SHOULD send an EHLO command as the first command after a successful TLS negotiation.

### Private Key Protection

**File Permissions**: Ensure private keys have restricted permissions:

```bash
# Set proper permissions on private key
chmod 600 /etc/ssl/private/mail.example.com.key
chown root:root /etc/ssl/private/mail.example.com.key
```

**In-Memory Handling**: When using `.data()` certificate source with password-protected keys:

```swift
let password = // Load from secure source (not hardcoded!)
let tlsConfig = TLSConfiguration(
    certificateSource: .data(
        certificateData: certData,
        privateKeyData: encryptedKeyData,
        password: password
    )
)
```

Never hardcode passwords in source code. Use:
- Environment variables
- Secure key management systems (AWS KMS, HashiCorp Vault)
- System keychains

### Certificate Validation

PrixFixe performs certificate validation through the platform's native TLS implementation:

- **macOS/iOS**: Security.framework validates certificates against system trust store
- **Linux**: OpenSSL validates certificates against system CA bundle

Ensure your certificates:
- Are not expired
- Have a valid chain to a trusted root CA
- Match the server domain (Common Name or Subject Alternative Name)

### TLS Version Policy

**Minimum Recommended**: TLS 1.2

Older versions (TLS 1.0, TLS 1.1) have known vulnerabilities and should not be used:

```swift
// DO NOT do this in production
let weakConfig = TLSConfiguration(
    certificateSource: .file(...),
    minimumTLSVersion: .tls10  // VULNERABLE
)

// Recommended
let secureConfig = TLSConfiguration(
    certificateSource: .file(...),
    minimumTLSVersion: .tls12  // SECURE
)
```

### Preventing Downgrade Attacks

PrixFixe prevents TLS downgrade attacks:

1. Once TLS is active, STARTTLS command is rejected:
```swift
guard !tlsActive else {
    return .rejected(response: "TLS already active")
}
```

2. State machine tracks TLS status independently
3. No way to downgrade from TLS to plaintext

## Troubleshooting

### Certificate Loading Errors

**Problem**: "Failed to load certificate"

**Solutions**:
```swift
// Check file paths are absolute
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/absolute/path/to/cert.pem",  // Not "cert.pem"
        privateKeyPath: "/absolute/path/to/key.pem"
    )
)

// Check file permissions
// $ ls -la /path/to/cert.pem
// Should be readable by the process user

// Verify file format (PEM)
// $ openssl x509 -in cert.pem -text -noout
```

### TLS Handshake Failures

**Problem**: "TLS handshake failed"

**Possible Causes**:
1. Certificate/key mismatch
2. Expired certificate
3. Unsupported TLS version
4. Invalid certificate chain

**Debugging**:
```bash
# Test certificate and key match
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5
# Hashes should match

# Check certificate validity
openssl x509 -in cert.pem -noout -dates

# Verify certificate chain
openssl verify -CAfile chain.pem cert.pem

# Test TLS connection
openssl s_client -connect mail.example.com:587 -starttls smtp
```

### OpenSSL Errors on Linux

**Problem**: "undefined symbol: SSL_CTX_new" or similar

**Solution**: Install OpenSSL development libraries:
```bash
sudo apt-get update
sudo apt-get install libssl-dev
```

**Problem**: OpenSSL version mismatch

**Solution**: Check OpenSSL version:
```bash
openssl version
# Should be 1.1.1 or higher

# Update if necessary
sudo apt-get update
sudo apt-get upgrade openssl libssl-dev
```

### Client Compatibility Issues

**Problem**: Some clients fail to negotiate TLS

**Solutions**:

1. Check minimum TLS version:
```swift
// Try lowering to TLS 1.2 if clients don't support 1.3
let tlsConfig = TLSConfiguration(
    certificateSource: .file(...),
    minimumTLSVersion: .tls12  // More compatible
)
```

2. Verify STARTTLS advertisement:
```bash
# Connect and check EHLO response
telnet mail.example.com 587
> EHLO client.example.com
# Should see "250-STARTTLS" in response
```

3. Enable debug logging to see TLS negotiation details

### Permission Denied Errors

**Problem**: "Permission denied" when reading certificate files

**Solutions**:
```bash
# Option 1: Fix file permissions
sudo chmod 644 /path/to/cert.pem
sudo chmod 600 /path/to/key.pem

# Option 2: Run as appropriate user
sudo -u smtp-user /path/to/server

# Option 3: Copy files to accessible location
cp /etc/ssl/private/key.pem /home/user/app/key.pem
chown user:user /home/user/app/key.pem
chmod 600 /home/user/app/key.pem
```

## Examples

### Production Server with Let's Encrypt

```swift
import PrixFixe
import PrixFixeCore
import PrixFixeNetwork

// Configure TLS with Let's Encrypt certificates
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/etc/letsencrypt/live/mail.example.com/fullchain.pem",
        privateKeyPath: "/etc/letsencrypt/live/mail.example.com/privkey.pem"
    ),
    minimumTLSVersion: .tls12
)

// Production server configuration
let config = ServerConfiguration(
    domain: "mail.example.com",
    port: 587,
    maxConnections: 1000,
    maxMessageSize: 25 * 1024 * 1024,  // 25 MB
    tlsConfiguration: tlsConfig
)

let server = SMTPServer(configuration: config)

server.messageHandler = { message in
    print("Received encrypted email from: \(message.from)")
    // Process message securely...
}

try await server.start()
print("Secure SMTP server listening on port 587")
```

### Development Server with Self-Signed Certificate

```swift
import PrixFixe
import PrixFixeCore
import PrixFixeNetwork

// Self-signed certificate for local development
let tlsConfig = TLSConfiguration(
    certificateSource: .selfSigned(commonName: "localhost")
)

// Development configuration
let config = ServerConfiguration(
    domain: "localhost",
    port: 2525,
    maxConnections: 10,
    maxMessageSize: 10 * 1024 * 1024,
    tlsConfiguration: tlsConfig
)

let server = SMTPServer(configuration: config)

server.messageHandler = { message in
    print("Received test email from: \(message.from)")
    print("Data size: \(message.data.count) bytes")
}

try await server.start()
print("Development SMTP server with TLS on port 2525")
```

### In-Memory Certificate Configuration

```swift
import PrixFixe
import PrixFixeCore
import PrixFixeNetwork

// Load certificates from secure storage
func loadCertificateFromKeychain() async throws -> (Data, Data) {
    // Load from keychain, database, or secure storage
    let certData = try await loadCertificate()
    let keyData = try await loadPrivateKey()
    return (certData, keyData)
}

// Configure with in-memory data
let (certData, keyData) = try await loadCertificateFromKeychain()

let tlsConfig = TLSConfiguration(
    certificateSource: .data(
        certificateData: certData,
        privateKeyData: keyData,
        password: nil
    ),
    minimumTLSVersion: .tls12
)

let config = ServerConfiguration(
    domain: "mail.example.com",
    port: 587,
    tlsConfiguration: tlsConfig
)

let server = SMTPServer(configuration: config)
try await server.start()
```

### High-Security Configuration

```swift
import PrixFixe
import PrixFixeCore
import PrixFixeNetwork

// Maximum security configuration
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/etc/ssl/certs/mail.example.com.pem",
        privateKeyPath: "/etc/ssl/private/mail.example.com.key"
    ),
    minimumTLSVersion: .tls13  // TLS 1.3 only
)

let config = ServerConfiguration(
    domain: "mail.example.com",
    port: 587,
    maxConnections: 500,
    maxMessageSize: 10 * 1024 * 1024,
    tlsConfiguration: tlsConfig
)

let server = SMTPServer(configuration: config)

server.messageHandler = { message in
    // Process with maximum security assurance
    print("Received TLS 1.3 encrypted email")
}

try await server.start()
```

### Testing TLS Configuration

```swift
import PrixFixe
import PrixFixeCore
import PrixFixeNetwork
import Testing

@Test func testTLSConfiguration() async throws {
    let tlsConfig = TLSConfiguration(
        certificateSource: .selfSigned(commonName: "test.local")
    )

    let config = ServerConfiguration(
        domain: "test.local",
        port: 2525,
        tlsConfiguration: tlsConfig
    )

    let server = SMTPServer(configuration: config)

    // Start server
    try await server.start()

    // Test STARTTLS command flow
    // 1. Connect to server
    // 2. Send EHLO
    // 3. Verify STARTTLS in capabilities
    // 4. Send STARTTLS
    // 5. Verify "220 Ready to start TLS" response

    try await server.stop()
}
```

## Additional Resources

- [RFC 5321 - Simple Mail Transfer Protocol](https://tools.ietf.org/html/rfc5321)
- [RFC 3207 - SMTP Service Extension for Secure SMTP over TLS](https://tools.ietf.org/html/rfc3207)
- [PrixFixe Integration Guide](../.plan/INTEGRATION.md)
- [PrixFixe API Documentation](https://yourusername.github.io/PrixFixe)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)

## Support

For issues, questions, or contributions:
- [GitHub Issues](https://github.com/yourusername/PrixFixe/issues)
- [Project Documentation](..)
- [Security Policy](../SECURITY.md)

---

**Security Note**: Always keep your TLS certificates and private keys secure. Never commit them to version control. Use proper file permissions and consider using hardware security modules (HSMs) or key management services for production deployments.
