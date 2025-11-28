/// PrixFixeMessage - Message Handling
///
/// Email message structures, parsing, and storage abstractions.

import Foundation

/// Represents a received email message
public struct EmailMessage: Sendable {
    /// The envelope sender (MAIL FROM)
    public let from: EmailAddress

    /// The envelope recipients (RCPT TO)
    public let recipients: [EmailAddress]

    /// The raw message data (headers + body)
    public let data: Data

    /// Initialize an email message
    public init(from: EmailAddress, recipients: [EmailAddress], data: Data) {
        self.from = from
        self.recipients = recipients
        self.data = data
    }
}

/// Represents an email address
public struct EmailAddress: Sendable, Hashable, CustomStringConvertible {
    /// The raw email address string
    public let address: String

    /// Initialize an email address
    /// - Parameter address: The email address string
    public init(_ address: String) {
        self.address = address
    }

    public var description: String {
        address
    }
}
