# Changelog

All notable changes to PrixFixe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## Version History

- **0.1.0** (2025-11-27): Initial release with RFC 5321 core compliance and multi-platform support

[Unreleased]: https://github.com/yourusername/PrixFixe/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/PrixFixe/releases/tag/v0.1.0
