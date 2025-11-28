import Testing
import Foundation
@testable import PrixFixeCore

@Suite("SMTP Command Parser Tests")
struct SMTPCommandTests {
    let parser = SMTPCommandParser()

    // MARK: - HELO / EHLO

    @Test("Parse HELO command")
    func testParseHelo() {
        let cmd = parser.parse("HELO client.example.com")

        if case .helo(let domain) = cmd {
            #expect(domain == "client.example.com")
        } else {
            Issue.record("Expected HELO command, got \(cmd)")
        }
    }

    @Test("Parse EHLO command")
    func testParseEhlo() {
        let cmd = parser.parse("EHLO client.example.com")

        if case .ehlo(let domain) = cmd {
            #expect(domain == "client.example.com")
        } else {
            Issue.record("Expected EHLO command")
        }
    }

    @Test("HELO is case-insensitive")
    func testHeloCaseInsensitive() {
        let variations = ["helo example.com", "HeLo example.com", "HELO example.com"]

        for variation in variations {
            let cmd = parser.parse(variation)
            if case .helo(let domain) = cmd {
                #expect(domain == "example.com")
            } else {
                Issue.record("Expected HELO for: \(variation)")
            }
        }
    }

    // MARK: - MAIL FROM

    @Test("Parse MAIL FROM with brackets")
    func testParseMailFromBrackets() {
        let cmd = parser.parse("MAIL FROM:<sender@example.com>")

        if case .mailFrom(let path) = cmd {
            #expect(path == "sender@example.com")
        } else {
            Issue.record("Expected MAIL FROM command")
        }
    }

    @Test("Parse MAIL FROM without brackets")
    func testParseMailFromNoBrackets() {
        let cmd = parser.parse("MAIL FROM:sender@example.com")

        if case .mailFrom(let path) = cmd {
            #expect(path == "sender@example.com")
        } else {
            Issue.record("Expected MAIL FROM command")
        }
    }

    @Test("Parse MAIL FROM with empty address (null sender)")
    func testParseMailFromEmpty() {
        let cmd = parser.parse("MAIL FROM:<>")

        if case .mailFrom(let path) = cmd {
            #expect(path == "")
        } else {
            Issue.record("Expected MAIL FROM with empty address")
        }
    }

    // MARK: - RCPT TO

    @Test("Parse RCPT TO with brackets")
    func testParseRcptToBrackets() {
        let cmd = parser.parse("RCPT TO:<recipient@example.com>")

        if case .rcptTo(let path) = cmd {
            #expect(path == "recipient@example.com")
        } else {
            Issue.record("Expected RCPT TO command")
        }
    }

    @Test("Parse RCPT TO without brackets")
    func testParseRcptToNoBrackets() {
        let cmd = parser.parse("RCPT TO:recipient@example.com")

        if case .rcptTo(let path) = cmd {
            #expect(path == "recipient@example.com")
        } else {
            Issue.record("Expected RCPT TO command")
        }
    }

    // MARK: - Simple Commands

    @Test("Parse DATA command")
    func testParseData() {
        let cmd = parser.parse("DATA")
        #expect(cmd == .data)
    }

    @Test("Parse RSET command")
    func testParseRset() {
        let cmd = parser.parse("RSET")
        #expect(cmd == .reset)
    }

    @Test("Parse NOOP command")
    func testParseNoop() {
        let cmd = parser.parse("NOOP")
        #expect(cmd == .noop)
    }

    @Test("Parse QUIT command")
    func testParseQuit() {
        let cmd = parser.parse("QUIT")
        #expect(cmd == .quit)
    }

    @Test("Parse VRFY command")
    func testParseVrfy() {
        let cmd = parser.parse("VRFY user@example.com")

        if case .verify(let address) = cmd {
            #expect(address == "user@example.com")
        } else {
            Issue.record("Expected VRFY command")
        }
    }

    // MARK: - STARTTLS

    @Test("Parse STARTTLS command")
    func testParseStartTLS() {
        let cmd = parser.parse("STARTTLS")
        #expect(cmd == .startTLS)
    }

    @Test("STARTTLS is case-insensitive")
    func testStartTLSCaseInsensitive() {
        let variations = ["starttls", "StartTLS", "STARTTLS", "sTaRtTlS"]

        for variation in variations {
            let cmd = parser.parse(variation)
            #expect(cmd == .startTLS, "Failed to parse: \(variation)")
        }
    }

    @Test("STARTTLS with trailing whitespace")
    func testStartTLSWithWhitespace() {
        let variations = ["STARTTLS ", "STARTTLS  ", "  STARTTLS  "]

        for variation in variations {
            let cmd = parser.parse(variation)
            #expect(cmd == .startTLS, "Failed to parse: '\(variation)'")
        }
    }

    @Test("STARTTLS does not accept parameters")
    func testStartTLSNoParameters() {
        // STARTTLS command should not have parameters
        // Any parameters are ignored by the parser (trimmed as whitespace)
        let cmd = parser.parse("STARTTLS")
        #expect(cmd == .startTLS)
        #expect(!cmd.requiresParameters)
    }

    // MARK: - Edge Cases

    @Test("Parse empty line")
    func testParseEmpty() {
        let cmd = parser.parse("")
        if case .unknown(let command) = cmd {
            #expect(command == "")
        } else {
            Issue.record("Expected unknown command for empty line")
        }
    }

    @Test("Parse whitespace only")
    func testParseWhitespace() {
        let cmd = parser.parse("   ")
        if case .unknown = cmd {
            // Expected
        } else {
            Issue.record("Expected unknown command for whitespace")
        }
    }

    @Test("Parse unknown command")
    func testParseUnknown() {
        let cmd = parser.parse("EXPN user")
        if case .unknown(let command) = cmd {
            #expect(command == "EXPN")
        } else {
            Issue.record("Expected unknown command")
        }
    }

    @Test("Parse command with extra whitespace")
    func testParseExtraWhitespace() {
        let cmd = parser.parse("  HELO   example.com  ")

        if case .helo(let domain) = cmd {
            #expect(domain == "example.com")
        } else {
            Issue.record("Expected HELO command")
        }
    }

    // MARK: - Command Properties

    @Test("Command verb extraction")
    func testCommandVerbs() {
        #expect(SMTPCommand.helo(domain: "test").verb == "HELO")
        #expect(SMTPCommand.ehlo(domain: "test").verb == "EHLO")
        #expect(SMTPCommand.mailFrom(reversePath: "test").verb == "MAIL")
        #expect(SMTPCommand.rcptTo(forwardPath: "test").verb == "RCPT")
        #expect(SMTPCommand.data.verb == "DATA")
        #expect(SMTPCommand.reset.verb == "RSET")
        #expect(SMTPCommand.noop.verb == "NOOP")
        #expect(SMTPCommand.quit.verb == "QUIT")
        #expect(SMTPCommand.startTLS.verb == "STARTTLS")
    }

    @Test("Command requires parameters")
    func testRequiresParameters() {
        #expect(SMTPCommand.helo(domain: "test").requiresParameters)
        #expect(SMTPCommand.ehlo(domain: "test").requiresParameters)
        #expect(SMTPCommand.mailFrom(reversePath: "test").requiresParameters)
        #expect(SMTPCommand.rcptTo(forwardPath: "test").requiresParameters)

        #expect(!SMTPCommand.data.requiresParameters)
        #expect(!SMTPCommand.reset.requiresParameters)
        #expect(!SMTPCommand.noop.requiresParameters)
        #expect(!SMTPCommand.quit.requiresParameters)
        #expect(!SMTPCommand.startTLS.requiresParameters)
    }

    @Test("Command description format")
    func testCommandDescription() {
        let helo = SMTPCommand.helo(domain: "example.com")
        #expect(helo.description == "HELO example.com")

        let mailFrom = SMTPCommand.mailFrom(reversePath: "user@example.com")
        #expect(mailFrom.description == "MAIL FROM:<user@example.com>")

        let data = SMTPCommand.data
        #expect(data.description == "DATA")
    }
}
