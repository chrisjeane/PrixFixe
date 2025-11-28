# PrixFixe Integration Guide

This guide will help you integrate PrixFixe into your Swift application to receive SMTP email messages.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Message Handling](#message-handling)
- [Platform-Specific Considerations](#platform-specific-considerations)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## Installation

### Swift Package Manager

Add PrixFixe to your `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        // Linux is implicitly supported
    ],
    dependencies: [
        .package(url: "https://github.com/yourusername/PrixFixe.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: ["PrixFixe"]
        )
    ]
)
```

### Xcode Project

1. Go to File > Add Package Dependencies
2. Enter the repository URL: `https://github.com/yourusername/PrixFixe.git`
3. Select version 0.1.0 or later
4. Add to your target

## Quick Start

### Basic Server

Create a simple SMTP server that prints received messages:

```swift
import PrixFixe

@main
struct MyApp {
    static func main() async throws {
        // Create server with default configuration
        let server = SMTPServer(configuration: .default)

        // Set up message handler
        server.messageHandler = { message in
            print("📧 Received email")
            print("From: \(message.from)")
            print("To: \(message.recipients.map { $0.address }.joined(separator: ", "))")

            if let content = String(data: message.data, encoding: .utf8) {
                print("Content:\n\(content)")
            }
        }

        // Start the server
        print("Starting SMTP server on port 2525...")
        try await server.start()
    }
}
```

### Testing Your Server

Test your server using telnet or a mail client:

```bash
# Connect to the server
telnet localhost 2525

# SMTP conversation:
# < 220 localhost ESMTP Service ready
EHLO client.example.com
# < 250-localhost Hello
# < 250-SIZE 10485760
# < 250 8BITMIME
MAIL FROM:<sender@example.com>
# < 250 Sender <sender@example.com> OK
RCPT TO:<recipient@example.com>
# < 250 Recipient <recipient@example.com> OK
DATA
# < 354 Start mail input; end with <CRLF>.<CRLF>
From: sender@example.com
To: recipient@example.com
Subject: Test Message

Hello from PrixFixe!
.
# < 250 Message accepted for delivery
QUIT
# < 221 localhost closing connection
```

## Configuration

### Server Configuration

Customize the server using `ServerConfiguration`:

```swift
let config = ServerConfiguration(
    domain: "mail.example.com",        // Server domain for SMTP greeting
    port: 2525,                        // Port to listen on
    maxConnections: 100,               // Maximum concurrent connections
    maxMessageSize: 10 * 1024 * 1024  // Maximum message size (10 MB)
)

let server = SMTPServer(configuration: config)
```

### Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `domain` | String | "localhost" | Server domain name used in SMTP responses |
| `port` | UInt16 | 2525 | TCP port to bind to |
| `maxConnections` | Int | 100 | Maximum concurrent connections |
| `maxMessageSize` | Int | 10 MB | Maximum message size in bytes |

### Port Selection

- **25**: Standard SMTP port (requires root/admin on Linux/macOS)
- **587**: Message submission port (typically used with STARTTLS)
- **2525**: Alternative non-privileged port (good for development)
- **Custom**: Any port above 1024 for non-privileged operation

## Message Handling

### Basic Message Handler

Process received messages with a closure:

```swift
server.messageHandler = { message in
    // Extract sender
    let sender = message.from.address

    // Extract recipients
    let recipients = message.recipients.map { $0.address }

    // Get message content
    if let content = String(data: message.data, encoding: .utf8) {
        // Process the message
        processEmail(from: sender, to: recipients, content: content)
    }
}
```

### Parsing Message Content

PrixFixe provides raw message data. Here's how to parse headers and body:

```swift
func parseMessage(_ data: Data) -> (headers: [String: String], body: String)? {
    guard let content = String(data: data, encoding: .utf8) else {
        return nil
    }

    // Split headers and body at blank line
    guard let separatorRange = content.range(of: "\r\n\r\n") else {
        return nil
    }

    let headersPart = String(content[..<separatorRange.lowerBound])
    let bodyPart = String(content[separatorRange.upperBound...])

    // Parse headers
    var headers: [String: String] = [:]
    for line in headersPart.components(separatedBy: "\r\n") {
        if let colonIndex = line.firstIndex(of: ":") {
            let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
    }

    return (headers, bodyPart)
}
```

Usage:

```swift
server.messageHandler = { message in
    if let (headers, body) = parseMessage(message.data) {
        print("Subject: \(headers["Subject"] ?? "(no subject)")")
        print("Body:\n\(body)")
    }
}
```

### Storing Messages

Store messages to disk or database:

```swift
import Foundation

class MessageStore {
    let storageDirectory: URL

    init(storageDirectory: URL) {
        self.storageDirectory = storageDirectory
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    func save(_ message: EmailMessage) throws {
        let filename = "\(UUID().uuidString).eml"
        let fileURL = storageDirectory.appendingPathComponent(filename)

        // Add envelope information as headers
        var fullMessage = """
        X-Envelope-From: \(message.from.address)
        X-Envelope-To: \(message.recipients.map { $0.address }.joined(separator: ", "))

        """

        if let content = String(data: message.data, encoding: .utf8) {
            fullMessage += content
        }

        try fullMessage.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

// Usage
let store = MessageStore(storageDirectory: URL(fileURLWithPath: "./mail"))
server.messageHandler = { message in
    try? store.save(message)
    print("Message saved to disk")
}
```

## Platform-Specific Considerations

### macOS

```swift
import PrixFixe
import PrixFixePlatform

// Check platform capabilities
let capabilities = PlatformCapabilities.current
print("Network.framework available: \(capabilities.hasNetworkFramework)")

// The server automatically uses Network.framework on macOS 13.0+
let server = SMTPServer(configuration: .default)
```

### Linux

```swift
// On Linux, Foundation sockets are used automatically
let config = ServerConfiguration(
    domain: "mail.example.com",
    port: 2525,
    maxConnections: 1000  // Linux can handle more connections
)

let server = SMTPServer(configuration: config)
```

### iOS

iOS has specific constraints for background execution:

```swift
import PrixFixe
import UIKit

class EmailServerManager {
    let server: SMTPServer

    init() {
        // Use conservative limits for iOS
        let config = ServerConfiguration(
            domain: "localhost",
            port: 2525,
            maxConnections: 10,  // Lower limit for mobile
            maxMessageSize: 5 * 1024 * 1024  // 5 MB
        )

        self.server = SMTPServer(configuration: config)

        // Set up message handler
        server.messageHandler = { [weak self] message in
            self?.handleMessage(message)
        }
    }

    func start() async throws {
        try await server.start()
    }

    func stop() async throws {
        try await server.stop()
    }

    private func handleMessage(_ message: EmailMessage) {
        // Process message on main queue for UI updates
        Task { @MainActor in
            // Update UI
        }
    }
}
```

**Important iOS Considerations:**
- The server will pause when the app enters background
- Use lower connection limits (5-10 recommended)
- Consider using local notifications for received messages
- Test thoroughly with background execution

## Error Handling

### Server Lifecycle Errors

```swift
do {
    try await server.start()
} catch ServerError.alreadyRunning {
    print("Server is already running")
} catch let error as NetworkError {
    print("Network error: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Common Errors

| Error | Type | Description | Solution |
|-------|------|-------------|----------|
| `alreadyRunning` | ServerError | Server already started | Check server state before starting |
| `bindFailed` | NetworkError | Cannot bind to port | Check port availability, permissions |
| `connectionClosed` | NetworkError | Client disconnected | Normal operation, no action needed |
| `messageTooLarge` | SMTPError | Message exceeds size limit | Increase `maxMessageSize` or reject |

### Graceful Shutdown

```swift
// Handle shutdown signals
import Foundation

let server = SMTPServer(configuration: .default)

// Set up signal handler for graceful shutdown
signal(SIGINT) { _ in
    print("\nShutting down server...")
    Task {
        try? await server.stop()
        exit(0)
    }
}

try await server.start()
```

## Best Practices

### 1. Always Set a Message Handler

```swift
// ❌ Bad: No message handler
let server = SMTPServer(configuration: .default)
try await server.start()  // Messages are silently discarded

// ✅ Good: Handler processes messages
server.messageHandler = { message in
    processMessage(message)
}
```

### 2. Use Appropriate Limits

```swift
// Development
let devConfig = ServerConfiguration(
    domain: "localhost",
    port: 2525,
    maxConnections: 10,
    maxMessageSize: 5 * 1024 * 1024
)

// Production
let prodConfig = ServerConfiguration(
    domain: "mail.example.com",
    port: 25,
    maxConnections: 1000,
    maxMessageSize: 25 * 1024 * 1024
)
```

### 3. Handle Errors Appropriately

```swift
server.messageHandler = { message in
    do {
        try processMessage(message)
    } catch {
        print("Error processing message: \(error)")
        // Log error, send alert, etc.
    }
}
```

### 4. Use Task Groups for Server Management

```swift
await withTaskGroup(of: Void.self) { group in
    // Start server in background task
    group.addTask {
        try? await server.start()
    }

    // Run other tasks concurrently
    group.addTask {
        await monitorServerHealth()
    }
}
```

### 5. Validate Message Content

```swift
server.messageHandler = { message in
    // Check sender
    guard !message.from.address.isEmpty else {
        print("Warning: Empty sender address")
        return
    }

    // Check recipients
    guard !message.recipients.isEmpty else {
        print("Warning: No recipients")
        return
    }

    // Validate message format
    guard String(data: message.data, encoding: .utf8) != nil else {
        print("Warning: Invalid UTF-8 content")
        return
    }

    // Process valid message
    processMessage(message)
}
```

## Examples

### Example 1: Development Email Catcher

Catch emails during development and display them:

```swift
import PrixFixe

@main
struct EmailCatcher {
    static func main() async throws {
        let server = SMTPServer(configuration: .default)

        server.messageHandler = { message in
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("From: \(message.from.address)")
            print("To: \(message.recipients.map { $0.address }.joined(separator: ", "))")

            if let content = String(data: message.data, encoding: .utf8),
               let (headers, body) = parseMessage(content) {
                print("Subject: \(headers["Subject"] ?? "(no subject)")")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print(body)
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            }
        }

        print("📬 Email Catcher started on port 2525")
        print("Configure your app to send to localhost:2525")
        try await server.start()
    }

    static func parseMessage(_ content: String) -> (headers: [String: String], body: String)? {
        guard let separatorRange = content.range(of: "\r\n\r\n") else {
            return nil
        }

        let headersPart = String(content[..<separatorRange.lowerBound])
        let bodyPart = String(content[separatorRange.upperBound...])

        var headers: [String: String] = [:]
        for line in headersPart.components(separatedBy: "\r\n") {
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex])
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        return (headers, bodyPart)
    }
}
```

### Example 2: Test Server for Integration Tests

Use PrixFixe in your test suite:

```swift
import Testing
import PrixFixe

@Suite("Email Integration Tests")
struct EmailIntegrationTests {
    var receivedMessages: [EmailMessage] = []
    let server: SMTPServer

    init() async throws {
        let config = ServerConfiguration(
            domain: "test.local",
            port: 2525,
            maxConnections: 10,
            maxMessageSize: 1024 * 1024
        )

        server = SMTPServer(configuration: config)

        server.messageHandler = { [weak self] message in
            self?.receivedMessages.append(message)
        }

        // Start server in background
        Task {
            try? await server.start()
        }

        // Wait for server to be ready
        try await Task.sleep(for: .milliseconds(100))
    }

    @Test("Receives email successfully")
    func testReceiveEmail() async throws {
        // Send test email to localhost:2525
        // ... your email sending code ...

        // Wait for message
        try await Task.sleep(for: .seconds(1))

        #expect(receivedMessages.count == 1)
        #expect(receivedMessages[0].from.address == "test@example.com")
    }
}
```

### Example 3: macOS Menu Bar App

Simple menu bar app that shows received email count:

```swift
import SwiftUI
import PrixFixe

@main
struct EmailMonitorApp: App {
    @StateObject private var emailMonitor = EmailMonitor()

    var body: some Scene {
        MenuBarExtra("📧 \(emailMonitor.messageCount)", systemImage: "envelope") {
            VStack {
                Text("Received: \(emailMonitor.messageCount) messages")
                Button("Clear") {
                    emailMonitor.clear()
                }
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
    }
}

@MainActor
class EmailMonitor: ObservableObject {
    @Published var messageCount = 0
    private var server: SMTPServer?

    init() {
        Task {
            await startServer()
        }
    }

    private func startServer() async {
        let server = SMTPServer(configuration: .default)

        server.messageHandler = { [weak self] message in
            Task { @MainActor in
                self?.messageCount += 1
            }
        }

        self.server = server

        try? await server.start()
    }

    func clear() {
        messageCount = 0
    }
}
```

## Troubleshooting

### Port Already in Use

**Problem**: Server fails to start with "Address already in use"

**Solutions**:
1. Check if another process is using the port:
   ```bash
   # macOS/Linux
   lsof -i :2525
   ```
2. Use a different port in configuration
3. Kill the process using the port
4. Wait for the OS to release the port (can take 30-60 seconds)

### Permission Denied on Port < 1024

**Problem**: Cannot bind to port 25, 587, etc.

**Solutions**:
1. Use a port above 1024 (e.g., 2525)
2. Run with elevated privileges (not recommended):
   ```bash
   sudo .build/release/YourApp
   ```
3. Use port forwarding:
   ```bash
   # Redirect port 25 to 2525
   sudo iptables -t nat -A PREROUTING -p tcp --dport 25 -j REDIRECT --to-port 2525
   ```

### Server Not Receiving Connections

**Problem**: Server starts but clients can't connect

**Solutions**:
1. Check firewall settings
2. Verify server is binding to correct address
3. Test with telnet locally first:
   ```bash
   telnet localhost 2525
   ```
4. Check if listening on all interfaces vs. localhost only

### Messages Not Being Processed

**Problem**: Server receives connections but messageHandler isn't called

**Solutions**:
1. Verify messageHandler is set before starting server
2. Check for errors in your message handler
3. Ensure client completes full SMTP transaction (including DATA and quit)
4. Add logging to verify message receipt:
   ```swift
   server.messageHandler = { message in
       print("Message handler called!")
       // Your processing code...
   }
   ```

### High Memory Usage

**Problem**: Server uses too much memory

**Solutions**:
1. Reduce `maxMessageSize`:
   ```swift
   let config = ServerConfiguration(
       maxMessageSize: 5 * 1024 * 1024  // 5 MB instead of 10 MB
   )
   ```
2. Reduce `maxConnections`
3. Process and discard messages quickly
4. Don't store messages in memory - write to disk

## Additional Resources

- [RFC 5321 - SMTP](https://tools.ietf.org/html/rfc5321)
- [Example Projects](Examples/)
- [API Documentation](https://yourusername.github.io/PrixFixe)
- [GitHub Issues](https://github.com/yourusername/PrixFixe/issues)

## Getting Help

If you encounter issues:

1. Check this integration guide
2. Review the [examples](Examples/)
3. Search [existing issues](https://github.com/yourusername/PrixFixe/issues)
4. Open a new issue with:
   - Swift version
   - Platform (macOS/Linux/iOS version)
   - Minimal reproduction code
   - Error messages

---

**Need more help?** Open an issue on GitHub or check the API documentation for detailed information about specific types and methods.
