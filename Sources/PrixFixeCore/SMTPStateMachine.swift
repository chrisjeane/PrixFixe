/// SMTP State Machine
///
/// Implements RFC 5321 state transitions and command sequence validation.
/// Ensures commands are received in the correct order.

import Foundation
import PrixFixeMessage

/// SMTP session states
public enum SMTPState: Sendable, Equatable {
    /// Initial state - no greeting received
    case initial

    /// Greeted - HELO or EHLO received
    case greeted

    /// Mail transaction started - MAIL FROM received
    case mail

    /// Recipients specified - one or more RCPT TO received
    case recipient

    /// Receiving message data - DATA command received
    case data

    /// Session ended - QUIT received
    case quit

    /// Human-readable description
    public var description: String {
        switch self {
        case .initial: return "Initial"
        case .greeted: return "Greeted"
        case .mail: return "Mail"
        case .recipient: return "Recipient"
        case .data: return "Data"
        case .quit: return "Quit"
        }
    }
}

/// Result of processing a command through the state machine
public enum SMTPCommandResult: Sendable {
    /// Command accepted, state transitioned
    case accepted(response: SMTPResponse, newState: SMTPState)

    /// Command rejected due to bad sequence
    case rejected(response: SMTPResponse)

    /// Command requires special handling (e.g., DATA content)
    case continueData

    /// Session should close
    case close(response: SMTPResponse)
}

/// SMTP state machine - validates command sequences
public struct SMTPStateMachine: Sendable {
    /// Current state
    public private(set) var state: SMTPState

    /// Current mail transaction
    public private(set) var transaction: MailTransaction?

    /// Server domain name
    private let domain: String

    /// Whether TLS is available (configured)
    public var tlsAvailable: Bool

    /// Whether TLS is currently active
    public var tlsActive: Bool

    /// Initialize the state machine
    /// - Parameters:
    ///   - domain: The server's domain name
    ///   - tlsAvailable: Whether TLS is configured and available
    public init(domain: String, tlsAvailable: Bool = false) {
        self.domain = domain
        self.state = .initial
        self.transaction = nil
        self.tlsAvailable = tlsAvailable
        self.tlsActive = false
    }

    /// Process a command and return the result
    /// - Parameter command: The SMTP command to process
    /// - Returns: The command processing result
    public mutating func process(_ command: SMTPCommand) -> SMTPCommandResult {
        switch command {
        case .helo(let clientDomain):
            return processHelo(clientDomain: clientDomain)

        case .ehlo(let clientDomain):
            return processEhlo(clientDomain: clientDomain)

        case .mailFrom(let reversePath):
            return processMailFrom(reversePath: reversePath)

        case .rcptTo(let forwardPath):
            return processRcptTo(forwardPath: forwardPath)

        case .data:
            return processData()

        case .reset:
            return processReset()

        case .noop:
            return processNoop()

        case .quit:
            return processQuit()

        case .verify:
            // VRFY is optional and often disabled for security
            return .rejected(response: .notImplemented("VRFY"))

        case .startTLS:
            return processStartTLS()

        case .unknown(let cmd):
            return .rejected(response: .syntaxError("Unknown command: \(cmd)"))
        }
    }

    // MARK: - Command Processors

    private mutating func processHelo(clientDomain: String) -> SMTPCommandResult {
        // HELO can be used in any state except QUIT
        guard state != .quit else {
            return .rejected(response: .badSequence("Session ended"))
        }

        // Reset any pending transaction
        transaction = nil

        state = .greeted
        return .accepted(
            response: SMTPResponse(code: .okay, message: "\(domain) Hello \(clientDomain)"),
            newState: .greeted
        )
    }

    private mutating func processEhlo(clientDomain: String) -> SMTPCommandResult {
        // EHLO can be used in any state except QUIT
        guard state != .quit else {
            return .rejected(response: .badSequence("Session ended"))
        }

        // Reset any pending transaction
        transaction = nil

        state = .greeted

        // Advertise capabilities
        var capabilities: [String] = []

        // Only advertise STARTTLS if TLS is available and not already active
        if tlsAvailable && !tlsActive {
            capabilities.append("STARTTLS")
        }

        capabilities.append(contentsOf: [
            "SIZE 10485760",  // Max message size: 10MB
            "8BITMIME"        // 8-bit MIME support
        ])

        return .accepted(
            response: .ehlo(domain: domain, capabilities: capabilities),
            newState: .greeted
        )
    }

    private mutating func processMailFrom(reversePath: String) -> SMTPCommandResult {
        // MAIL FROM requires HELO/EHLO first
        guard state == .greeted || state == .recipient || state == .mail else {
            if state == .initial {
                return .rejected(response: .badSequence("Send HELO/EHLO first"))
            }
            return .rejected(response: .badSequence("Bad sequence of commands"))
        }

        // Start new transaction
        transaction = MailTransaction(from: reversePath)
        state = .mail

        return .accepted(
            response: .ok("Sender \(reversePath.isEmpty ? "<>" : "<\(reversePath)>") OK"),
            newState: .mail
        )
    }

    private mutating func processRcptTo(forwardPath: String) -> SMTPCommandResult {
        // RCPT TO requires MAIL FROM first
        guard state == .mail || state == .recipient else {
            if state == .greeted {
                return .rejected(response: .badSequence("Send MAIL FROM first"))
            }
            return .rejected(response: .badSequence("Bad sequence of commands"))
        }

        // Add recipient to transaction
        guard var txn = transaction else {
            return .rejected(response: .badSequence("No mail transaction"))
        }

        txn.addRecipient(forwardPath)
        transaction = txn
        state = .recipient

        return .accepted(
            response: .ok("Recipient <\(forwardPath)> OK"),
            newState: .recipient
        )
    }

    private mutating func processData() -> SMTPCommandResult {
        // DATA requires at least one RCPT TO
        guard state == .recipient else {
            if state == .greeted {
                return .rejected(response: .badSequence("Send MAIL FROM first"))
            } else if state == .mail {
                return .rejected(response: .badSequence("Send RCPT TO first"))
            }
            return .rejected(response: .badSequence("Bad sequence of commands"))
        }

        state = .data

        return .accepted(
            response: .startMailInput,
            newState: .data
        )
    }

    private mutating func processReset() -> SMTPCommandResult {
        // RSET is valid in any state except QUIT
        guard state != .quit else {
            return .rejected(response: .badSequence("Session ended"))
        }

        // Clear transaction and return to greeted state
        transaction = nil
        state = .greeted

        return .accepted(
            response: .ok("Reset OK"),
            newState: .greeted
        )
    }

    private mutating func processNoop() -> SMTPCommandResult {
        // NOOP is always valid (except after QUIT)
        guard state != .quit else {
            return .rejected(response: .badSequence("Session ended"))
        }

        return .accepted(
            response: .ok("OK"),
            newState: state  // No state change
        )
    }

    private mutating func processQuit() -> SMTPCommandResult {
        state = .quit
        return .close(response: .closing(domain: domain))
    }

    private mutating func processStartTLS() -> SMTPCommandResult {
        // STARTTLS only valid in greeted state (after EHLO/HELO)
        guard state == .greeted else {
            if state == .initial {
                return .rejected(response: .badSequence("Send EHLO/HELO first"))
            }
            return .rejected(response: .badSequence("STARTTLS not allowed in current state"))
        }

        // Cannot use STARTTLS if TLS is already active
        guard !tlsActive else {
            return .rejected(response: SMTPResponse(code: .commandNotImplemented, message: "TLS already active"))
        }

        // Cannot use STARTTLS if TLS is not configured
        guard tlsAvailable else {
            return .rejected(response: SMTPResponse(code: .commandNotImplemented, message: "STARTTLS not available"))
        }

        // Signal that TLS upgrade should happen
        // State will reset to .initial after upgrade (per RFC 3207)
        // The session handler must perform the actual TLS upgrade
        return .accepted(
            response: SMTPResponse(code: .serviceReady, message: "Ready to start TLS"),
            newState: .initial  // Reset to initial after TLS upgrade
        )
    }

    // MARK: - Data Handling

    /// Complete the current DATA transfer with message content
    /// - Parameter messageData: The raw message data
    /// - Returns: The result of completing the data transfer
    public mutating func completeData(messageData: Data) -> SMTPCommandResult {
        guard state == .data else {
            return .rejected(response: .badSequence("Not in DATA state"))
        }

        guard var txn = transaction else {
            return .rejected(response: .badSequence("No mail transaction"))
        }

        // Store message data
        txn.messageData = messageData

        // Transaction complete - return to greeted state
        // Note: EmailMessage is created in SMTPSession where the messageHandler is invoked
        transaction = nil
        state = .greeted

        return .accepted(
            response: .ok("Message accepted for delivery"),
            newState: .greeted
        )
    }

    /// Get the current mail transaction
    public func currentTransaction() -> MailTransaction? {
        transaction
    }

    /// Reset the state machine (for testing or errors)
    public mutating func reset() {
        state = .initial
        transaction = nil
    }
}

/// Mail transaction data
public struct MailTransaction: Sendable {
    /// Sender (reverse path)
    public let from: String

    /// Recipients (forward paths)
    public private(set) var recipients: [String]

    /// Message data (set during DATA command)
    public var messageData: Data?

    /// Initialize a new mail transaction
    /// - Parameter from: The sender address
    public init(from: String) {
        self.from = from
        self.recipients = []
        self.messageData = nil
    }

    /// Add a recipient to the transaction
    /// - Parameter recipient: The recipient address
    public mutating func addRecipient(_ recipient: String) {
        recipients.append(recipient)
    }
}
