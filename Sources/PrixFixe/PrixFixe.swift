/// PrixFixe - Lightweight Embedded SMTP Server
///
/// A cross-platform SMTP server library for Swift supporting Linux, macOS, and iOS.
///
/// ## Overview
///
/// PrixFixe is a lightweight, embeddable SMTP server designed to receive email messages
/// in Swift applications. It provides RFC 5321 core compliance with IPv6 support.
///
/// ## Example Usage
///
/// ```swift
/// import PrixFixe
///
/// let server = SMTPServer(configuration: .default)
/// server.messageHandler = { message in
///     print("Received email from: \(message.from)")
/// }
/// try await server.start()
/// ```
///
/// ## Key Features
///
/// - **Multi-platform**: Runs on Linux, macOS, and iOS
/// - **IPv6-first**: Built-in IPv6 support with IPv4 compatibility
/// - **Modern Swift**: Leverages async/await and actors
/// - **Embeddable**: Library-first design for integration into host applications
/// - **RFC Compliant**: Implements RFC 5321 core SMTP commands

// Re-export all public APIs from submodules
@_exported import PrixFixeCore
@_exported import PrixFixeNetwork
@_exported import PrixFixeMessage
@_exported import PrixFixePlatform
