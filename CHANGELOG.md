# Changelog

All notable changes to PrixFixe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-11-28

### Added

#### TLS/STARTTLS Support
- **STARTTLS Command**: Full RFC 3207 STARTTLS implementation for opportunistic TLS upgrade
- **TLSConfiguration Structure**: Comprehensive TLS configuration with multiple certificate source options:
  - File-based certificates (PEM format)
  - In-memory certificate data with optional password support
  - Self-signed certificate generation for development
- **Platform-Native TLS Implementations**:
  - macOS/iOS: Security.framework integration (native, no dependencies)
  - Linux: OpenSSL integration (requires libssl-dev)
- **TLS Protocol Support**: TLS 1.0, 1.1, 1.2, and 1.3 with configurable minimum version
- **Security Measures**:
  - Automatic buffer clearance before TLS upgrade (prevents plaintext leakage)
  - State machine reset after TLS upgrade (requires fresh EHLO)
  - No TLS downgrade allowed (once active, stays active)
  - STARTTLS only advertised when appropriate (before TLS activation)
- **SMTPStateMachine TLS Support**:
  - `tlsAvailable` flag to track TLS configuration status
  - `tlsActive` flag to track active TLS connections
  - STARTTLS command validation and state transitions
  - Dynamic EHLO capability advertisement based on TLS state
- **NetworkConnection TLS Protocol**:
  - `startTLS()` method for connection upgrade
  - `isTLSActive` property to query encryption status
  - Platform-specific TLS implementations in FoundationSocket
- **Comprehensive Testing**: 108 TLS-specific tests covering:
  - TLSConfiguration validation
  - STARTTLS state machine transitions
  - Buffer security during upgrade
  - Platform-specific TLS implementations
  - Error handling and edge cases
  - Integration tests for complete STARTTLS flow

#### Documentation
- **TLS Guide** (`Documentation/TLS-GUIDE.md`): Comprehensive 800+ line guide covering:
  - Certificate requirements and generation
  - Configuration options with examples
  - Platform differences (macOS vs Linux)
  - Security considerations and best practices
  - Troubleshooting common TLS issues
  - Production and development examples
- **Enhanced README**: Added TLS/STARTTLS sections with:
  - Quick start example with TLS configuration
  - Platform requirements (OpenSSL on Linux)
  - Updated feature list and status
  - TLS-specific installation instructions
- **DocC Enhancements**: Added comprehensive documentation to:
  - `TLSConfiguration` with usage examples
  - `NetworkConnection.startTLS()` with security notes
  - `SMTPSession.handleStartTLS()` with implementation details
  - `SMTPStateMachine.processStartTLS()` with RFC compliance notes
  - `SMTPStateMachine.processEhlo()` with capability advertisement logic

### Changed

#### API Updates
- **ServerConfiguration**: Added `tlsConfiguration: TLSConfiguration?` parameter
- **SessionConfiguration**: Added `tlsConfiguration: TLSConfiguration?` parameter
- **SMTPStateMachine**: Added `tlsAvailable` and `tlsActive` properties for TLS state tracking
- **EHLO Response**: Now dynamically includes/excludes STARTTLS based on TLS state
- **Package.swift**: Added OpenSSL linking for Linux platform (`libssl` and `libcrypto`)

#### Implementation Changes
- **SMTPSession**: Enhanced with TLS upgrade logic and buffer security measures
- **FoundationSocket**: Added platform-specific TLS implementations:
  - `startTLS_Darwin()` for macOS/iOS using Security.framework
  - `startTLS_Linux()` for Linux using OpenSSL C bindings
- **SMTPCommand**: Added `.startTLS` case to command enumeration
- **SMTPCommandParser**: Added STARTTLS command parsing

### Security

#### TLS Security Measures
- **Buffer Clearance**: Automatic clearance of read-ahead buffers before TLS upgrade prevents plaintext leakage
- **State Reset**: SMTP state machine resets after TLS upgrade, requiring fresh authentication
- **No Downgrade**: Once TLS is active, it cannot be downgraded to plaintext
- **Certificate Validation**: Platform-native certificate validation via Security.framework (macOS/iOS) and OpenSSL (Linux)
- **Configurable TLS Versions**: Support for enforcing minimum TLS version (1.2+ recommended)
- **Secure Defaults**: TLS 1.2 minimum by default, platform-selected secure cipher suites

### Platform Support

#### Linux Requirements
- **OpenSSL Development Libraries**: Required for TLS support
  - Ubuntu/Debian: `libssl-dev`
  - Fedora/RHEL: `openssl-devel`
  - Alpine: `openssl-dev`
- **Automatic Linking**: Package.swift automatically links OpenSSL on Linux platforms

#### macOS/iOS
- **No Additional Dependencies**: Uses system-provided Security.framework
- **Native Integration**: Full platform integration with macOS/iOS security infrastructure

### Fixed
- N/A (new feature release)

### Deprecated
- N/A (no deprecations in this release)

### Removed
- N/A (no removals in this release)

---

## [0.1.0] - 2025-11-27

### Added

#### Core Features
- **SMTP Server Implementation**: Full RFC 5321 core compliance with support for HELO, EHLO, MAIL FROM, RCPT TO, DATA, QUIT, RSET, and NOOP commands
- **Multi-Platform Support**: Native support for Linux (Ubuntu 22.04+), macOS (13.0+), and iOS (16.0+)
- **IPv6-First Networking**: Built-in IPv6 support with IPv4-mapped address compatibility
- **Automatic Transport Selection**: Platform-aware networking using Network.framework on macOS/iOS and Foundation sockets on Linux
- **Modern Concurrency**: Actor-based architecture using Swift async/await for safe concurrent operations
- **Production-Ready Features**:
  - Configurable connection timeouts (5 minutes default)
  - Configurable command timeouts (1 minute default)
  - Message size limits (10 MB default, configurable)
  - Maximum concurrent connections (100 default, configurable)
  - Graceful connection handling and error recovery

#### API & Architecture
- **SMTPServer Actor**: Thread-safe server with lifecycle management (start/stop)
- **ServerConfiguration**: Flexible configuration for domain, port, connection limits, and message size
- **EmailMessage**: Simple structure containing envelope sender, recipients, and raw message data
- **NetworkTransport Protocol**: Platform-agnostic networking abstraction
- **SocketFactory**: Automatic platform-appropriate transport creation
- **Platform Detection**: Runtime platform capability detection

#### Networking Implementations
- **NetworkFrameworkSocket**: High-performance implementation using Apple's Network.framework (macOS 13.0+, iOS 16.0+)
- **FoundationSocket**: POSIX socket-based implementation for Linux and older macOS versions
- **SocketAddress**: IPv6-first address representation with IPv4-mapped address support
- **Dual-Stack Support**: Automatic IPv4/IPv6 compatibility

#### Developer Experience
- **Comprehensive Documentation**: DocC-compatible documentation for all public APIs
- **137 Tests**: Extensive test coverage across all modules (128 core tests passing)
- **Zero External Dependencies**: Pure Swift implementation using only Foundation and Network.framework
- **Example Application**: SimpleServer command-line example demonstrating basic usage
- **Clean Architecture**: Modular design with clear separation of concerns

#### Platform-Specific Features
- **Linux**: Foundation socket implementation with full IPv6 support
- **macOS**: Network.framework with path monitoring and optimized performance
- **iOS**: Network.framework with background execution awareness

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Security
- **Input Validation**: All SMTP commands validated before processing
- **Resource Limits**: Configurable limits prevent resource exhaustion
- **Command Timeout Protection**: Prevents slow-read attacks
- **Connection Timeout Protection**: Prevents idle connection resource exhaustion

## Release Notes

### v0.1.0 - Initial Release

PrixFixe 0.1.0 is the first public release of this lightweight, embeddable SMTP server library for Swift. This release focuses on core SMTP receiving functionality with production-ready features including timeouts, resource limits, and comprehensive error handling.

#### Highlights
- RFC 5321 core compliance
- Full multi-platform support (Linux, macOS, iOS)
- IPv6-first with IPv4 compatibility
- Modern Swift concurrency (async/await, actors)
- Zero external dependencies
- Production-ready with comprehensive timeout handling

#### Known Limitations (Planned for Future Releases)
- No STARTTLS/TLS encryption support
- No SMTP AUTH authentication
- No SMTP sending/relay capability (receive-only)
- No DKIM/SPF validation
- No advanced ESMTP extensions (SIZE and 8BITMIME only)

#### Platform Status
- **Linux**: Fully supported and tested on Ubuntu 22.04 LTS
- **macOS**: Fully supported and tested on macOS 13.0+ (128/137 tests passing on macOS 26.1 beta)
- **iOS**: Implementation complete, UI example application pending

#### Getting Started

```swift
import PrixFixe

let server = SMTPServer(configuration: .default)

server.messageHandler = { message in
    print("Received email from: \(message.from)")
    // Process message...
}

try await server.start()
```

See the [README](README.md) for full documentation and examples.

#### Contributors
- Initial implementation and architecture
- Comprehensive test suite
- Multi-platform networking layer
- Documentation and examples

---

## Release Notes

### v0.2.0 - STARTTLS/TLS Support

PrixFixe 0.2.0 adds complete STARTTLS/TLS encryption support with platform-native implementations. This major feature release provides production-ready TLS capabilities while maintaining backward compatibility with v0.1.0 configurations.

#### Highlights
- RFC 3207 STARTTLS implementation with state machine integration
- Platform-native TLS: Security.framework (macOS/iOS), OpenSSL (Linux)
- Flexible certificate configuration (file, data, self-signed)
- TLS 1.2/1.3 support with configurable minimum version
- Critical security measures: buffer clearance, state reset, no downgrade
- 108 comprehensive TLS tests
- Extensive documentation with TLS guide

#### Migration from v0.1.0

Existing v0.1.0 configurations continue to work without changes. To enable TLS:

```swift
// Add TLS configuration to your existing ServerConfiguration
let tlsConfig = TLSConfiguration(
    certificateSource: .file(
        certificatePath: "/path/to/cert.pem",
        privateKeyPath: "/path/to/key.pem"
    )
)

let config = ServerConfiguration(
    domain: "mail.example.com",
    port: 587,
    tlsConfiguration: tlsConfig  // Add this parameter
)
```

#### Breaking Changes
- None - v0.2.0 is backward compatible with v0.1.0

#### Known Limitations
- Client certificate validation (mutual TLS) not yet implemented
- Custom cipher suite support is platform-specific

#### Platform Requirements
- **Linux**: Requires OpenSSL development libraries (`libssl-dev`)
- **macOS/iOS**: No additional dependencies (uses system Security.framework)

See [Documentation/TLS-GUIDE.md](Documentation/TLS-GUIDE.md) for complete TLS configuration documentation.

---

### v0.1.0 - Initial Release

See v0.1.0 release notes below for details on the initial release.

---

## Version History

- **0.2.0** (2025-11-28): STARTTLS/TLS encryption support with platform-native implementations
- **0.1.0** (2025-11-27): Initial release with RFC 5321 core compliance and multi-platform support

[Unreleased]: https://github.com/yourusername/PrixFixe/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/yourusername/PrixFixe/releases/tag/v0.2.0
[0.1.0]: https://github.com/yourusername/PrixFixe/releases/tag/v0.1.0
