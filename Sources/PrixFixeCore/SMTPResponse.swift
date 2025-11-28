/// SMTP Response Codes and Formatting
///
/// Implements RFC 5321 response codes and formatting for SMTP server replies.

import Foundation

/// SMTP response status codes (RFC 5321)
public enum SMTPResponseCode: Int, Sendable {
    // 2xx - Positive Completion
    case systemStatus = 211
    case helpMessage = 214
    case serviceReady = 220
    case serviceClosing = 221
    case okay = 250
    case userNotLocal = 251
    case cannotVerify = 252

    // 3xx - Positive Intermediate
    case startMailInput = 354

    // 4xx - Transient Negative Completion
    case serviceNotAvailable = 421
    case mailboxBusy = 450
    case localError = 451
    case insufficientStorage = 452

    // 5xx - Permanent Negative Completion
    case syntaxError = 500
    case syntaxErrorInParameters = 501
    case commandNotImplemented = 502
    case badSequence = 503
    case parameterNotImplemented = 504
    case mailboxUnavailable = 550
    case userNotLocalTryForward = 551
    case exceededStorageAllocation = 552
    case mailboxNameNotAllowed = 553
    case transactionFailed = 554

    /// Whether this is a positive response (2xx or 3xx)
    public var isPositive: Bool {
        rawValue < 400
    }

    /// Whether this is an error response (4xx or 5xx)
    public var isError: Bool {
        rawValue >= 400
    }

    /// Whether this is a transient error (4xx)
    public var isTransient: Bool {
        rawValue >= 400 && rawValue < 500
    }

    /// Whether this is a permanent error (5xx)
    public var isPermanent: Bool {
        rawValue >= 500
    }
}

/// SMTP response message
public struct SMTPResponse: Sendable {
    /// The response code
    public let code: SMTPResponseCode

    /// The response message (can be multiline)
    public let message: String

    /// Whether this is a multiline response
    public let isMultiline: Bool

    /// Initialize a single-line SMTP response
    /// - Parameters:
    ///   - code: The response code
    ///   - message: The response message
    public init(code: SMTPResponseCode, message: String) {
        self.code = code
        self.message = message
        self.isMultiline = false
    }

    /// Initialize a multiline SMTP response
    /// - Parameters:
    ///   - code: The response code
    ///   - lines: Multiple lines of response text
    public init(code: SMTPResponseCode, lines: [String]) {
        self.code = code
        self.message = lines.joined(separator: "\r\n")
        self.isMultiline = lines.count > 1
    }

    // MARK: - Common Responses

    /// Service ready greeting (220)
    public static func serviceReady(domain: String) -> SMTPResponse {
        SMTPResponse(code: .serviceReady, message: "\(domain) ESMTP Service ready")
    }

    /// Closing connection (221)
    public static func closing(domain: String) -> SMTPResponse {
        SMTPResponse(code: .serviceClosing, message: "\(domain) closing connection")
    }

    /// OK response (250)
    public static func ok(_ message: String = "OK") -> SMTPResponse {
        SMTPResponse(code: .okay, message: message)
    }

    /// Start mail input (354)
    public static let startMailInput = SMTPResponse(
        code: .startMailInput,
        message: "Start mail input; end with <CRLF>.<CRLF>"
    )

    /// Syntax error (500)
    public static func syntaxError(_ message: String = "Syntax error") -> SMTPResponse {
        SMTPResponse(code: .syntaxError, message: message)
    }

    /// Bad sequence of commands (503)
    public static func badSequence(_ message: String = "Bad sequence of commands") -> SMTPResponse {
        SMTPResponse(code: .badSequence, message: message)
    }

    /// Command not implemented (502)
    public static func notImplemented(_ command: String) -> SMTPResponse {
        SMTPResponse(code: .commandNotImplemented, message: "Command \(command) not implemented")
    }

    /// Message too large (552)
    public static let messageTooLarge = SMTPResponse(
        code: .exceededStorageAllocation,
        message: "Message exceeds maximum size"
    )

    /// Service not available (421)
    public static func serviceNotAvailable(_ message: String = "Service not available") -> SMTPResponse {
        SMTPResponse(code: .serviceNotAvailable, message: message)
    }

    /// Local error (451)
    public static func localError(_ message: String = "Local error") -> SMTPResponse {
        SMTPResponse(code: .localError, message: message)
    }

    /// EHLO response with capabilities
    public static func ehlo(domain: String, capabilities: [String] = []) -> SMTPResponse {
        var lines = ["\(domain) Hello"]
        lines.append(contentsOf: capabilities)
        return SMTPResponse(code: .okay, lines: lines)
    }

    // MARK: - Formatting

    /// Format the response for transmission over the wire
    ///
    /// RFC 5321 format:
    /// - Single line: "250 OK\r\n"
    /// - Multiline: "250-First line\r\n250-Second line\r\n250 Last line\r\n"
    public func formatted() -> String {
        if !isMultiline || !message.contains("\r\n") {
            // Single line response
            return "\(code.rawValue) \(message)\r\n"
        }

        // Multiline response
        let lines = message.components(separatedBy: "\r\n")
        var result = ""

        for (index, line) in lines.enumerated() {
            let separator = index < lines.count - 1 ? "-" : " "
            result += "\(code.rawValue)\(separator)\(line)\r\n"
        }

        return result
    }

    /// Convert to Data for network transmission
    public func data() -> Data {
        Data(formatted().utf8)
    }
}

// MARK: - CustomStringConvertible

extension SMTPResponse: CustomStringConvertible {
    public var description: String {
        formatted().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
