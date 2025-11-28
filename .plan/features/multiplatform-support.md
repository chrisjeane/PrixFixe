# Multi-Platform Support

**Date**: 2025-11-27
**Status**: Planning
**Complexity**: L

## Overview

PrixFixe is designed to run on Linux, macOS, and iOS with a unified codebase and platform-specific optimizations where necessary.

## Platform Requirements

### Linux
- **Minimum Version**: Ubuntu 22.04 LTS (or equivalent)
- **Swift Version**: 6.0+
- **Networking**: Foundation sockets (BSD sockets)
- **Target Use Cases**: Development, testing, embedded server

### macOS
- **Minimum Version**: macOS 13.0 (Ventura)
- **Swift Version**: 6.0+
- **Networking**: Network.framework (preferred), Foundation fallback
- **Target Use Cases**: Development, testing, embedded server

### iOS
- **Minimum Version**: iOS 16.0
- **Swift Version**: 6.0+
- **Networking**: Network.framework
- **Target Use Cases**: Testing, embedded development server

## Platform-Specific Features

### Linux

**Networking**:
- Foundation BSD socket wrapper
- Direct socket control (SO_REUSEADDR, SO_REUSEPORT)
- IPv6 dual-stack support

**Capabilities**:
- High connection count (100+)
- Large message sizes (10MB+)
- Long-running server processes

**Optimizations**:
- Socket options tuned for performance
- Efficient concurrent connection handling
- Optional SwiftNIO backend (future)

**Constraints**:
- No Network.framework
- Manual socket lifecycle management

---

### macOS

**Networking**:
- Network.framework (preferred)
- Modern networking APIs
- First-class IPv6 support

**Capabilities**:
- High connection count (100+)
- Large message sizes (10MB+)
- Long-running processes

**Optimizations**:
- Network.framework automatic path monitoring
- Efficient connection management
- Low-level TLS support (future)

**Constraints**:
- macOS 13+ for latest Network.framework features
- Firewall may prompt user

---

### iOS

**Networking**:
- Network.framework (required)
- Background task API for graceful degradation

**Capabilities**:
- Limited connection count (5-10 recommended)
- Moderate message sizes (1-5MB recommended)
- Foreground-only reliable operation

**Optimizations**:
- Lower resource usage defaults
- Aggressive timeout handling
- Memory-conscious configuration

**Constraints**:
- Background execution severely limited
- App lifecycle impacts server
- Memory constraints
- No listening on privileged ports
- Network permissions required
- App Store restrictions on network services

## Platform Abstraction Strategy

### Socket Abstraction

```swift
// Platform-agnostic protocol
public protocol SocketProtocol: Sendable {
    func bind(host: String, port: Int) async throws
    func listen(backlog: Int) async throws
    func accept() async throws -> Connection
    func close() async throws
}

// Implementations per platform
class FoundationSocket: SocketProtocol { }        // Linux, macOS (fallback)
class NetworkFrameworkSocket: SocketProtocol { }  // macOS, iOS (preferred)
```

### Platform Selection

```swift
let socket: SocketProtocol = {
    #if canImport(Network)
    return NetworkFrameworkSocket()  // macOS, iOS
    #else
    return FoundationSocket()        // Linux
    #endif
}()
```

## IPv6 Support Across Platforms

### IPv6 Binding

| Platform | IPv6 Support | Dual-Stack | Notes |
|----------|-------------|-----------|-------|
| Linux | Full | Yes | `::` binds to IPv4 and IPv6 by default |
| macOS | Full | Yes | Network.framework handles dual-stack |
| iOS | Full | Yes | Same as macOS |

### Address Formats

**Supported Everywhere**:
- `::1` - IPv6 localhost
- `::` - IPv6 any address (all interfaces)
- `::ffff:192.0.2.1` - IPv4-mapped IPv6

**Platform Differences**:
- Linux: May require `IPV6_V6ONLY=0` for dual-stack
- macOS/iOS: Network.framework handles dual-stack automatically

## Resource Limits by Platform

### Default Configurations

| Resource | Linux | macOS | iOS |
|----------|-------|-------|-----|
| Max Connections | 100 | 100 | 10 |
| Max Message Size | 10 MB | 10 MB | 1 MB |
| Idle Timeout | 5 min | 5 min | 2 min |
| Data Timeout | 10 min | 10 min | 5 min |
| Listen Port | 2525 | 2525 | Ephemeral |

### Rationale

**iOS Constraints**:
- Limited memory (mobile device)
- Background restrictions
- Battery concerns
- App lifecycle interruptions

**Linux/macOS**:
- Server-oriented workloads
- More resources available
- Long-running processes expected

## Platform Capabilities API

```swift
public struct PlatformCapabilities {
    public static var current: PlatformCapabilities { get }

    public let platform: Platform
    public let supportsBackgroundExecution: Bool
    public let preferredSocketImplementation: SocketType
    public let maxRecommendedConnections: Int
    public let maxRecommendedMessageSize: Int
    public let supportsLongRunning: Bool
}

public enum Platform {
    case linux
    case macOS
    case iOS
}

public enum SocketType {
    case foundation
    case networkFramework
}
```

### Usage

```swift
let capabilities = PlatformCapabilities.current

let config = ServerConfiguration(
    maxConnections: capabilities.maxRecommendedConnections,
    maxMessageSize: capabilities.maxRecommendedMessageSize
)
```

## iOS-Specific Considerations

### Background Execution

**Limitations**:
- iOS suspends apps in background after ~30 seconds
- Network services cannot run indefinitely in background
- Background URLSession doesn't apply (not HTTP)

**Strategy**:
- Foreground-only by default
- Finish current sessions on background transition
- No new connections accepted in background
- Optional: Use background task API for graceful shutdown

### Implementation

```swift
#if os(iOS)
actor BackgroundTaskManager {
    func applicationDidEnterBackground() async {
        // Stop accepting new connections
        await server.stopAccepting()

        // Begin background task
        let taskID = beginBackgroundTask()

        // Allow current sessions to complete (with timeout)
        await server.drainSessions(timeout: .seconds(25))

        // End background task
        endBackgroundTask(taskID)
    }

    func applicationWillEnterForeground() async {
        // Resume accepting connections
        await server.resumeAccepting()
    }
}
#endif
```

### App Lifecycle Integration

```swift
// In iOS app
@main
struct MyApp: App {
    @StateObject private var serverManager = SMTPServerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification
                )) { _ in
                    serverManager.pause()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification
                )) { _ in
                    serverManager.resume()
                }
        }
    }
}
```

### Memory Management

```swift
#if os(iOS)
// Respond to memory warnings
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    // Reduce connection limit
    // Clear message cache
    // Aggressive cleanup
}
#endif
```

## Testing Strategy

### Platform-Specific Tests

**Unit Tests**:
- Run on all platforms
- Platform-agnostic logic

**Integration Tests**:
- Platform-specific socket implementations
- IPv6 binding and connectivity
- Resource limit enforcement

**CI/CD Matrix**:
```yaml
strategy:
  matrix:
    platform: [ubuntu-latest, macos-latest, ios-simulator]
    swift: ['6.0']
```

### Platform Validation Checklist

- [ ] Unit tests pass on Linux
- [ ] Unit tests pass on macOS
- [ ] Unit tests pass on iOS simulator
- [ ] Integration tests pass on Linux
- [ ] Integration tests pass on macOS
- [ ] Integration tests pass on iOS simulator
- [ ] IPv6 binding works on all platforms
- [ ] Example apps run on all platforms
- [ ] Performance is acceptable on all platforms

## Documentation Requirements

### Platform-Specific Guides

1. **Linux Setup Guide**
   - Installing Swift
   - Building and running
   - Systemd integration (optional)

2. **macOS Setup Guide**
   - Xcode requirements
   - Running from command line
   - Firewall considerations

3. **iOS Integration Guide**
   - Adding to Xcode project
   - App lifecycle integration
   - Background behavior
   - App Store considerations

### API Documentation

- Mark iOS-specific APIs with `@available(iOS 16.0, *)`
- Document platform differences in doc comments
- Provide platform-specific examples

## Build Configuration

### Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrixFixe",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .linux
    ],
    products: [
        .library(name: "PrixFixe", targets: ["PrixFixe"])
    ],
    targets: [
        .target(
            name: "PrixFixe",
            dependencies: ["PrixFixeCore", "PrixFixeNetwork"]
        ),
        .target(
            name: "PrixFixeCore",
            dependencies: ["PrixFixeNetwork", "PrixFixePlatform"]
        ),
        .target(
            name: "PrixFixeNetwork",
            dependencies: ["PrixFixePlatform"]
        ),
        .target(
            name: "PrixFixePlatform",
            dependencies: []
        ),
        .testTarget(
            name: "PrixFixeTests",
            dependencies: ["PrixFixe"]
        )
    ]
)
```

### Conditional Compilation

```swift
#if canImport(Network)
import Network
// Network.framework code
#endif

#if os(iOS)
import UIKit
// iOS-specific code
#endif

#if os(Linux)
import Glibc
// Linux-specific code
#endif
```

## Success Criteria

- [ ] Single codebase runs on all three platforms
- [ ] No platform-specific code in public API
- [ ] Platform capabilities queryable at runtime
- [ ] Reasonable defaults per platform
- [ ] Examples for each platform
- [ ] Platform-specific documentation
- [ ] CI/CD validates all platforms
- [ ] Performance acceptable on all platforms

## Future Enhancements

### SwiftNIO Backend (Linux)
- Optional high-performance backend for Linux
- Better concurrency for high-load scenarios
- Maintains same public API

### watchOS Support
- Ultra-minimal embedded server
- Extreme resource constraints
- Post-1.0 consideration

### tvOS Support
- Similar to iOS constraints
- Limited use cases
- Low priority

## Platform Comparison Summary

| Aspect | Linux | macOS | iOS |
|--------|-------|-------|-----|
| **Networking API** | Foundation | Network.framework | Network.framework |
| **Performance** | High | High | Moderate |
| **Resource Limits** | High | High | Low |
| **Background Running** | Yes | Yes | No |
| **Primary Use Case** | Server | Development | Testing |
| **Complexity** | Medium | Low | High |
| **Constraints** | None significant | Firewall prompts | Many (background, memory, lifecycle) |

## Conclusion

Multi-platform support is a core feature of PrixFixe, achieved through careful abstraction and platform-aware defaults. Each platform has its strengths and constraints, which are accommodated through the platform capabilities API and sensible defaults.
