# PrixFixe System Architecture

**Date**: 2025-11-27
**Status**: Planning
**Overall Complexity**: XL

## Overview

PrixFixe is a lightweight embedded SMTP server designed to run across Linux, macOS, and iOS platforms. The architecture prioritizes protocol compliance, platform abstraction, and embeddability for integration into host applications.

## Design Principles

1. **Lightweight**: Minimal dependencies, small memory footprint
2. **Embeddable**: Library-first design, not a standalone daemon
3. **Protocol Compliant**: RFC 5321 (SMTP) core compliance
4. **Platform Agnostic**: Unified API with platform-specific optimizations
5. **Modern Swift**: Leverage Swift Concurrency, structured concurrency patterns
6. **Testable**: Clean separation of concerns, dependency injection ready

## System Components

### 1. Network Layer (`PrixFixeNetwork`)
**Responsibility**: Platform-agnostic networking abstractions

- **SocketProtocol**: Abstract socket interface
- **IPv6SocketManager**: IPv6-first implementation with IPv4 fallback
- **ConnectionHandler**: Accept and manage client connections
- **StreamReader/Writer**: Async stream processing

**Platform Implementations**:
- Linux: Foundation.Socket or SwiftNIO
- macOS: Network.framework
- iOS: Network.framework with background limitations

### 2. SMTP Protocol Layer (`PrixFixeSMTP`)
**Responsibility**: SMTP protocol state machine and command handling

- **SMTPServer**: Main server orchestrator
- **SMTPSession**: Per-connection session state
- **SMTPStateMachine**: RFC 5321 state transitions
- **CommandParser**: Parse and validate SMTP commands
- **ResponseFormatter**: Generate RFC-compliant responses

**Commands Supported**:
- Core: HELO, EHLO, MAIL FROM, RCPT TO, DATA, QUIT
- Extended: RSET, NOOP, VRFY (optional)

### 3. Message Handling Layer (`PrixFixeMessage`)
**Responsibility**: Email message processing and storage

- **MessageReceiver**: Stream email data during DATA command
- **MessageValidator**: Basic header and structure validation
- **MessageStore**: Abstract storage interface
- **MessageDelegate**: Callback protocol for host applications

**Storage Strategies**:
- In-memory (default, for testing)
- File-based (simple persistence)
- Custom (delegate-based for host integration)

### 4. Configuration Layer (`PrixFixeConfig`)
**Responsibility**: Server configuration and policies

- **ServerConfig**: Port, host, limits, feature flags
- **SecurityPolicy**: Connection limits, rate limiting, size limits
- **FeatureFlags**: Enable/disable SMTP extensions

### 5. Platform Abstraction Layer (`PrixFixePlatform`)
**Responsibility**: Handle platform-specific differences

- **PlatformCapabilities**: Query available features per platform
- **BackgroundTaskManager**: iOS background execution handling
- **ResourceLimits**: Platform-specific constraints

## Component Dependencies

```
┌─────────────────────────────────────────┐
│         Host Application                │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│      SMTPServer (Public API)            │
└─────┬──────────────────────────┬────────┘
      │                          │
      ▼                          ▼
┌──────────────┐        ┌─────────────────┐
│ SMTPSession  │◄───────┤ MessageDelegate │
│ (per-client) │        └─────────────────┘
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ SMTPStateMachine     │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ CommandParser/       │
│ ResponseFormatter    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ ConnectionHandler    │
│ (Network Layer)      │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Platform-Specific    │
│ Socket Implementation│
└──────────────────────┘
```

## Concurrency Model

- **Swift Concurrency**: Actor-based for session management
- **Structured Concurrency**: Task groups for connection handling
- **Thread Safety**: Actors for shared state (connection pools, metrics)

```swift
actor SMTPServer {
    private var sessions: [UUID: SMTPSession] = [:]

    func start() async throws {
        await withTaskGroup(of: Void.self) { group in
            // Accept connections
        }
    }
}
```

## Data Flow: Receiving an Email

1. **Connection**: Client connects → `ConnectionHandler` accepts
2. **Greeting**: Server sends 220 greeting via `SMTPSession`
3. **Handshake**: Client sends EHLO → `CommandParser` validates → `SMTPStateMachine` transitions
4. **Envelope**: MAIL FROM, RCPT TO commands → state transitions, validation
5. **Data Transfer**: DATA command → `MessageReceiver` streams content
6. **Processing**: Complete message → `MessageDelegate` callback to host app
7. **Response**: 250 OK → `ResponseFormatter` sends confirmation
8. **Completion**: QUIT → session cleanup

## Security Considerations

- **No Authentication**: Phase 1 does not include AUTH (future extension)
- **No TLS**: STARTTLS deferred to later phase
- **Input Validation**: Strict command parsing, size limits
- **Resource Limits**: Max connections, max message size, timeouts
- **IPv6 Security**: Proper address validation and handling

## Testing Strategy

- **Unit Tests**: Per-component using SwiftTest
- **Integration Tests**: Full SMTP session flows
- **Platform Tests**: Platform-specific validation on Linux, macOS, iOS
- **Conformance Tests**: RFC 5321 compliance testing
- **Performance Tests**: Connection handling, throughput benchmarks

## Deployment Models

### As Embedded Library
```swift
import PrixFixe

let server = SMTPServer(config: .default)
server.messageHandler = { message in
    // Process received email
}
try await server.start()
```

### As Test Server (for app testing)
```swift
let testServer = SMTPServer(config: .ephemeralPort)
try await testServer.start()
// Use in integration tests
```

### iOS Specific
```swift
// Limited background execution
let server = SMTPServer(config: .iosOptimized)
server.backgroundTaskPolicy = .finishCurrentOnly
```

## Open Architectural Questions

1. **SwiftNIO vs Foundation Networking**: Should we support SwiftNIO as an option for Linux high-performance scenarios?
2. **iOS Background Modes**: How to handle network service advertisement in background?
3. **Message Size Limits**: Default limits per platform (iOS more restrictive)?
4. **Metrics/Observability**: Should we include structured logging/metrics from the start?

## Success Criteria

- [ ] Clean API surface area (< 10 public types)
- [ ] Zero required dependencies beyond stdlib/Foundation
- [ ] Passes RFC 5321 core command compliance tests
- [ ] Runs on all three target platforms
- [ ] Handles 100+ concurrent connections (Linux/macOS)
- [ ] < 5MB memory footprint for basic server
- [ ] Comprehensive test coverage (> 80%)
