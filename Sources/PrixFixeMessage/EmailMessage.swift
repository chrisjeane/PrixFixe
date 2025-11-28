/// PrixFixeMessage - Message Handling
///
/// Email message structures, parsing, and storage abstractions.

import Foundation

/// Represents a complete received email message with envelope information.
///
/// `EmailMessage` contains both the SMTP envelope information (sender and recipients)
/// and the raw message data (headers and body). This structure is passed to your
/// message handler when a message is successfully received.
///
/// ## Overview
///
/// The message includes:
/// - **Envelope sender**: The address from the MAIL FROM command
/// - **Envelope recipients**: Addresses from RCPT TO commands
/// - **Raw data**: The complete message content including headers and body
///
/// ## Example
///
/// ```swift
/// server.messageHandler = { message in
///     print("From: \(message.from)")
///
///     for recipient in message.recipients {
///         print("To: \(recipient)")
///     }
///
///     // Parse message content
///     if let content = String(data: message.data, encoding: .utf8) {
///         // Process headers and body
///         let lines = content.split(separator: "\r\n")
///         // ...
///     }
/// }
/// ```
///
/// - Note: PrixFixe provides the raw message data. You can use a separate library
///   for parsing MIME content, headers, or other email-specific formats.
public struct EmailMessage: Sendable {
    /// The envelope sender address from the MAIL FROM command.
    ///
    /// This is the address that specified who is sending the message,
    /// which may differ from the From: header in the message content.
    public let from: EmailAddress

    /// The envelope recipient addresses from RCPT TO commands.
    ///
    /// These are the addresses that the sender specified as recipients,
    /// which may differ from To:, Cc:, or Bcc: headers in the message content.
    public let recipients: [EmailAddress]

    /// The raw message data including all headers and body content.
    ///
    /// This is the complete message as transmitted during the DATA phase,
    /// encoded as UTF-8. The data includes:
    /// - All message headers (From, To, Subject, etc.)
    /// - The blank line separating headers from body
    /// - The message body
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let content = String(data: message.data, encoding: .utf8) {
    ///     // Split into headers and body
    ///     if let headerEndIndex = content.range(of: "\r\n\r\n") {
    ///         let headers = String(content[..<headerEndIndex.lowerBound])
    ///         let body = String(content[headerEndIndex.upperBound...])
    ///         // Process...
    ///     }
    /// }
    /// ```
    public let data: Data

    /// Initialize a new email message.
    ///
    /// - Parameters:
    ///   - from: The envelope sender address.
    ///   - recipients: The envelope recipient addresses.
    ///   - data: The raw message data.
    public init(from: EmailAddress, recipients: [EmailAddress], data: Data) {
        self.from = from
        self.recipients = recipients
        self.data = data
    }
}

/// Represents an email address from SMTP envelope commands.
///
/// This is a simple wrapper around the email address string as received
/// in MAIL FROM and RCPT TO commands. No validation or parsing is performed
/// beyond basic SMTP syntax checking.
///
/// ## Example
///
/// ```swift
/// let address = EmailAddress("user@example.com")
/// print(address)  // "user@example.com"
/// ```
public struct EmailAddress: Sendable, Hashable, CustomStringConvertible {
    /// The raw email address string.
    ///
    /// This is the address as received in the SMTP command,
    /// with angle brackets removed.
    ///
    /// Examples:
    /// - "user@example.com"
    /// - "admin@mail.server.com"
    /// - "" (empty reverse path in MAIL FROM:<>)
    public let address: String

    /// Initialize an email address.
    ///
    /// - Parameter address: The email address string.
    ///
    /// - Note: No validation is performed. The address is stored as-is.
    public init(_ address: String) {
        self.address = address
    }

    /// The string representation of the email address.
    public var description: String {
        address
    }
}
