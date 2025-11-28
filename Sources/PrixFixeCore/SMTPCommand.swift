/// SMTP Command Types and Parsing
///
/// Implements RFC 5321 SMTP command parsing and representation.

import Foundation

/// SMTP commands supported by the server
public enum SMTPCommand: Sendable, Equatable {
    /// HELO command - Simple SMTP greeting
    case helo(domain: String)

    /// EHLO command - Extended SMTP greeting
    case ehlo(domain: String)

    /// MAIL FROM command - Specify sender
    case mailFrom(reversePath: String)

    /// RCPT TO command - Specify recipient
    case rcptTo(forwardPath: String)

    /// DATA command - Begin message content transfer
    case data

    /// RSET command - Reset the session
    case reset

    /// NOOP command - No operation
    case noop

    /// QUIT command - End session
    case quit

    /// VRFY command - Verify address (optional, often disabled)
    case verify(address: String)

    /// STARTTLS command - Upgrade connection to TLS
    case startTLS

    /// Unknown or unsupported command
    case unknown(command: String)

    // MARK: - Command Properties

    /// The verb of this command (e.g., "HELO", "MAIL")
    public var verb: String {
        switch self {
        case .helo: return "HELO"
        case .ehlo: return "EHLO"
        case .mailFrom: return "MAIL"
        case .rcptTo: return "RCPT"
        case .data: return "DATA"
        case .reset: return "RSET"
        case .noop: return "NOOP"
        case .quit: return "QUIT"
        case .verify: return "VRFY"
        case .startTLS: return "STARTTLS"
        case .unknown(let cmd): return cmd
        }
    }

    /// Whether this command requires parameters
    public var requiresParameters: Bool {
        switch self {
        case .helo, .ehlo, .mailFrom, .rcptTo, .verify:
            return true
        case .data, .reset, .noop, .quit, .startTLS, .unknown:
            return false
        }
    }
}

/// SMTP command parser
public struct SMTPCommandParser: Sendable {

    public init() {}

    /// Parse a raw SMTP command line
    /// - Parameter line: The command line (without trailing CRLF)
    /// - Returns: The parsed command
    public func parse(_ line: String) -> SMTPCommand {
        // Trim whitespace
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            return .unknown(command: "")
        }

        // Split into command and parameters
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let commandPart = parts.first else {
            return .unknown(command: trimmed)
        }

        let command = String(commandPart).uppercased()
        let parameters = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""

        // Parse based on command
        switch command {
        case "HELO":
            guard !parameters.isEmpty else {
                return .unknown(command: trimmed)
            }
            return .helo(domain: parameters)

        case "EHLO":
            guard !parameters.isEmpty else {
                return .unknown(command: trimmed)
            }
            return .ehlo(domain: parameters)

        case "MAIL":
            return parseMailFrom(parameters)

        case "RCPT":
            return parseRcptTo(parameters)

        case "DATA":
            return .data

        case "RSET":
            return .reset

        case "NOOP":
            return .noop

        case "QUIT":
            return .quit

        case "VRFY":
            guard !parameters.isEmpty else {
                return .unknown(command: trimmed)
            }
            return .verify(address: parameters)

        case "STARTTLS":
            return .startTLS

        default:
            return .unknown(command: command)
        }
    }

    // MARK: - Parameter Parsing

    /// Parse MAIL FROM:<address>
    private func parseMailFrom(_ params: String) -> SMTPCommand {
        // Expected format: FROM:<reverse-path>
        guard params.uppercased().hasPrefix("FROM:") else {
            return .unknown(command: "MAIL \(params)")
        }

        let pathStart = params.index(params.startIndex, offsetBy: 5)
        let path = String(params[pathStart...]).trimmingCharacters(in: .whitespaces)

        // Extract address from <...>
        let reversePath = extractAddress(from: path)
        return .mailFrom(reversePath: reversePath)
    }

    /// Parse RCPT TO:<address>
    private func parseRcptTo(_ params: String) -> SMTPCommand {
        // Expected format: TO:<forward-path>
        guard params.uppercased().hasPrefix("TO:") else {
            return .unknown(command: "RCPT \(params)")
        }

        let pathStart = params.index(params.startIndex, offsetBy: 3)
        let path = String(params[pathStart...]).trimmingCharacters(in: .whitespaces)

        // Extract address from <...>
        let forwardPath = extractAddress(from: path)
        return .rcptTo(forwardPath: forwardPath)
    }

    /// Extract email address from <...> brackets
    /// - Parameter path: The path string (may or may not have brackets)
    /// - Returns: The extracted address
    private func extractAddress(from path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespaces)

        // Check for <...> format
        if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") {
            let start = trimmed.index(after: trimmed.startIndex)
            let end = trimmed.index(before: trimmed.endIndex)
            return String(trimmed[start..<end])
        }

        // Return as-is if no brackets
        return trimmed
    }
}

// MARK: - CustomStringConvertible

extension SMTPCommand: CustomStringConvertible {
    public var description: String {
        switch self {
        case .helo(let domain):
            return "HELO \(domain)"
        case .ehlo(let domain):
            return "EHLO \(domain)"
        case .mailFrom(let path):
            return "MAIL FROM:<\(path)>"
        case .rcptTo(let path):
            return "RCPT TO:<\(path)>"
        case .data:
            return "DATA"
        case .reset:
            return "RSET"
        case .noop:
            return "NOOP"
        case .quit:
            return "QUIT"
        case .verify(let addr):
            return "VRFY \(addr)"
        case .startTLS:
            return "STARTTLS"
        case .unknown(let cmd):
            return "UNKNOWN: \(cmd)"
        }
    }
}
