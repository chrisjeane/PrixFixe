# PrixFixe Component Structure

**Date**: 2025-11-27
**Status**: Planning

## Module Organization

PrixFixe will be organized as a Swift Package with multiple targets:

```
PrixFixe/
├── Sources/
│   ├── PrixFixe/                    # Main module (re-exports)
│   ├── PrixFixeCore/                # Core SMTP implementation
│   ├── PrixFixeNetwork/             # Network abstractions
│   ├── PrixFixeMessage/             # Message handling
│   └── PrixFixePlatform/            # Platform-specific code
├── Tests/
│   ├── PrixFixeCoreTests/
│   ├── PrixFixeNetworkTests/
│   ├── PrixFixeMessageTests/
│   └── PrixFixeIntegrationTests/
├── Examples/
│   ├── SimpleServer/                # Basic server example
│   ├── EmbeddedServer/              # Integration example
│   └── iOSTestServer/               # iOS-specific example
└── Package.swift
```

## Component Details

### PrixFixeNetwork Module

**Purpose**: Platform-agnostic networking primitives

#### Core Types

```swift
// Abstract socket interface
public protocol SocketProtocol: Sendable {
    func bind(host: String, port: Int) async throws
    func listen(backlog: Int) async throws
    func accept() async throws -> Connection
    func close() async throws
}

// Connection abstraction
public protocol Connection: Sendable {
    var remoteAddress: SocketAddress { get }
    func read(maxBytes: Int) async throws -> Data
    func write(_ data: Data) async throws
    func close() async throws
}

// Address handling (IPv6-first)
public struct SocketAddress: Sendable, Hashable {
    public let host: String
    public let port: Int
    public let isIPv6: Bool
}
```

#### Platform Implementations

- `FoundationSocket.swift` - Cross-platform fallback
- `NetworkFrameworkSocket.swift` - macOS/iOS optimized
- `LinuxSocket.swift` - Linux-specific optimizations (if needed)

**Complexity**: M

---

### PrixFixeCore Module

**Purpose**: SMTP protocol state machine and command handling

#### Core Types

```swift
// Main server actor
public actor SMTPServer {
    public init(configuration: ServerConfiguration)
    public func start() async throws
    public func stop() async throws
    public var messageHandler: MessageHandler? { get set }
}

// Per-connection session
actor SMTPSession {
    let id: UUID
    let connection: Connection
    var state: SMTPState

    func run() async throws
}

// State machine
enum SMTPState {
    case initial
    case greeted(domain: String)
    case mailFrom(sender: String)
    case rcptTo(sender: String, recipients: [String])
    case receivingData(envelope: Envelope)
    case completed
    case error
}

// Command parser
struct SMTPCommand {
    enum Kind {
        case helo(domain: String)
        case ehlo(domain: String)
        case mailFrom(address: String, parameters: [String: String])
        case rcptTo(address: String, parameters: [String: String])
        case data
        case quit
        case rset
        case noop
        case unknown(String)
    }

    static func parse(_ line: String) -> Result<SMTPCommand, SMTPError>
}

// Response builder
struct SMTPResponse {
    let code: Int
    let message: String
    let isMultiline: Bool

    func formatted() -> String
}
```

**Complexity**: XL

---

### PrixFixeMessage Module

**Purpose**: Email message processing and storage

#### Core Types

```swift
// Message representation
public struct EmailMessage: Sendable {
    public let id: UUID
    public let envelope: Envelope
    public let headers: [String: String]
    public let body: Data
    public let receivedAt: Date
}

// Envelope information
public struct Envelope: Sendable {
    public let from: EmailAddress
    public let to: [EmailAddress]
    public let timestamp: Date
}

// Email address parsing
public struct EmailAddress: Sendable, Hashable {
    public let localPart: String
    public let domain: String

    public var description: String { "\(localPart)@\(domain)" }

    public static func parse(_ string: String) -> EmailAddress?
}

// Message handler protocol
public protocol MessageHandler: Sendable {
    func handleMessage(_ message: EmailMessage) async throws
}

// Message receiver (streams DATA)
actor MessageReceiver {
    func receive(from connection: Connection) async throws -> EmailMessage
}
```

**Complexity**: M

---

### PrixFixePlatform Module

**Purpose**: Platform detection and capability handling

#### Core Types

```swift
// Platform capabilities
public struct PlatformCapabilities {
    public static var current: PlatformCapabilities { get }

    public let platform: Platform
    public let supportsBackgroundExecution: Bool
    public let preferredSocketImplementation: SocketType
    public let maxConcurrentConnections: Int
    public let defaultMessageSizeLimit: Int
}

public enum Platform {
    case linux
    case macOS
    case iOS
}

// iOS background task management
#if os(iOS)
public actor BackgroundTaskManager {
    public func beginTask(name: String) -> BackgroundTaskID
    public func endTask(_ id: BackgroundTaskID)
}
#endif
```

**Complexity**: S

---

### PrixFixe Module (Main)

**Purpose**: Public API and convenience re-exports

```swift
// Re-export public API
@_exported import PrixFixeCore
@_exported import PrixFixeMessage

// Convenience builders
public extension SMTPServer {
    static func `default`() -> SMTPServer {
        SMTPServer(configuration: .default)
    }

    static func ephemeral() -> SMTPServer {
        SMTPServer(configuration: .ephemeralPort)
    }
}

// Configuration presets
public extension ServerConfiguration {
    static var `default`: ServerConfiguration {
        ServerConfiguration(
            host: "::",  // IPv6 any
            port: 2525,  // Non-privileged
            maxConnections: 100,
            maxMessageSize: 10_485_760  // 10MB
        )
    }

    static var ephemeralPort: ServerConfiguration {
        var config = ServerConfiguration.default
        config.port = 0  // OS-assigned
        return config
    }

    #if os(iOS)
    static var iosOptimized: ServerConfiguration {
        ServerConfiguration(
            host: "::1",  // Localhost only
            port: 0,
            maxConnections: 5,
            maxMessageSize: 1_048_576  // 1MB
        )
    }
    #endif
}
```

**Complexity**: XS

---

## Configuration Types

```swift
public struct ServerConfiguration: Sendable {
    public var host: String
    public var port: Int
    public var maxConnections: Int
    public var maxMessageSize: Int
    public var connectionTimeout: Duration
    public var greeting: String
    public var enabledExtensions: Set<SMTPExtension>
}

public enum SMTPExtension: String, CaseIterable {
    case eightBitMIME = "8BITMIME"
    case size = "SIZE"
    case pipelining = "PIPELINING"
    // Future: STARTTLS, AUTH, etc.
}
```

## Error Handling

```swift
public enum SMTPError: Error, Sendable {
    case networkError(underlying: Error)
    case protocolViolation(String)
    case invalidCommand(String)
    case messageTooLarge
    case tooManyRecipients
    case connectionClosed
    case timeout
    case unsupportedExtension(String)
}

public enum PrixFixeError: Error, Sendable {
    case serverNotStarted
    case serverAlreadyRunning
    case bindFailed(String)
    case platformUnsupported(reason: String)
}
```

## Thread Safety Model

- **Actors**: `SMTPServer`, `SMTPSession`, `MessageReceiver`
- **Sendable**: All configuration and data types
- **@unchecked Sendable**: Only for platform-specific socket handles (carefully)
- **No `@MainActor`**: Library should not assume main actor

## Testing Support

```swift
// Test doubles
public protocol MockableSocket: SocketProtocol {
    var recordedWrites: [Data] { get }
    func simulateRead(_ data: Data)
}

// Test utilities
public struct SMTPTestClient {
    public init(server: SMTPServer)
    public func connect() async throws
    public func send(command: String) async throws -> String
    public func sendMail(from: String, to: [String], body: String) async throws
}
```

## Dependencies

### External (Swift Package Manager)
- **SwiftTest**: Test framework (dev dependency only)
- **None**: Zero runtime dependencies (stdlib + Foundation only)

### Internal Module Dependencies
```
PrixFixe
├── depends on: PrixFixeCore, PrixFixeMessage
PrixFixeCore
├── depends on: PrixFixeNetwork, PrixFixeMessage, PrixFixePlatform
PrixFixeNetwork
├── depends on: PrixFixePlatform
PrixFixeMessage
├── depends on: None (standalone)
PrixFixePlatform
├── depends on: None (standalone)
```

## File Organization Example

```
Sources/PrixFixeCore/
├── SMTPServer.swift
├── SMTPSession.swift
├── SMTPStateMachine.swift
├── Commands/
│   ├── SMTPCommand.swift
│   ├── CommandParser.swift
│   └── CommandValidator.swift
├── Responses/
│   ├── SMTPResponse.swift
│   └── ResponseCodes.swift
└── Configuration/
    ├── ServerConfiguration.swift
    └── SMTPExtension.swift

Sources/PrixFixeNetwork/
├── SocketProtocol.swift
├── Connection.swift
├── SocketAddress.swift
├── Platform/
│   ├── FoundationSocket.swift
│   ├── NetworkFrameworkSocket.swift
│   └── LinuxSocket.swift (conditional)
└── ConnectionPool.swift

Sources/PrixFixeMessage/
├── EmailMessage.swift
├── Envelope.swift
├── EmailAddress.swift
├── MessageHandler.swift
├── MessageReceiver.swift
└── Validation/
    ├── HeaderValidator.swift
    └── AddressParser.swift

Sources/PrixFixePlatform/
├── PlatformCapabilities.swift
├── Platform.swift
└── iOS/
    └── BackgroundTaskManager.swift (conditional)
```

## Public API Surface Area Target

**Goal**: Keep public API minimal and focused

- Public types: ~15-20
- Public protocols: ~5-7
- Public functions/methods: ~30-40

This ensures ease of learning and maintains backward compatibility.
