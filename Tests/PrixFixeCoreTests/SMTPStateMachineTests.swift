import Testing
import Foundation
@testable import PrixFixeCore

@Suite("SMTP State Machine Tests")
struct SMTPStateMachineTests {

    // MARK: - Initial State

    @Test("Initial state is correct")
    func testInitialState() {
        let sm = SMTPStateMachine(domain: "mail.example.com")
        #expect(sm.state == .initial)
        #expect(sm.currentTransaction() == nil)
    }

    @Test("Cannot send MAIL before HELO")
    func testMailBeforeHelo() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        let result = sm.process(.mailFrom(reversePath: "sender@example.com"))

        if case .rejected(let response) = result {
            #expect(response.code == .badSequence)
        } else {
            Issue.record("Expected rejection")
        }

        #expect(sm.state == .initial)
    }

    // MARK: - HELO/EHLO

    @Test("HELO transitions to greeted state")
    func testHelo() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        let result = sm.process(.helo(domain: "client.example.com"))

        if case .accepted(let response, let newState) = result {
            #expect(newState == .greeted)
            #expect(response.code == .okay)
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.state == .greeted)
    }

    @Test("EHLO transitions to greeted state")
    func testEhlo() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        let result = sm.process(.ehlo(domain: "client.example.com"))

        if case .accepted(let response, let newState) = result {
            #expect(newState == .greeted)
            #expect(response.code == .okay)
            #expect(response.isMultiline)  // EHLO has capabilities
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.state == .greeted)
    }

    @Test("HELO can reset session")
    func testHeloReset() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        // Start a transaction
        _ = sm.process(.ehlo(domain: "client"))
        _ = sm.process(.mailFrom(reversePath: "sender@example.com"))

        #expect(sm.currentTransaction() != nil)

        // HELO resets the transaction
        _ = sm.process(.helo(domain: "client"))

        #expect(sm.state == .greeted)
        #expect(sm.currentTransaction() == nil)
    }

    // MARK: - MAIL FROM

    @Test("MAIL FROM after HELO")
    func testMailFrom() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        let result = sm.process(.mailFrom(reversePath: "sender@example.com"))

        if case .accepted(let response, let newState) = result {
            #expect(newState == .mail)
            #expect(response.code == .okay)
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.state == .mail)
        #expect(sm.currentTransaction()?.from == "sender@example.com")
    }

    @Test("MAIL FROM with empty address (null sender)")
    func testMailFromEmpty() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        let result = sm.process(.mailFrom(reversePath: ""))

        if case .accepted(_, let newState) = result {
            #expect(newState == .mail)
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.currentTransaction()?.from == "")
    }

    // MARK: - RCPT TO

    @Test("RCPT TO after MAIL FROM")
    func testRcptTo() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        _ = sm.process(.mailFrom(reversePath: "sender@example.com"))

        let result = sm.process(.rcptTo(forwardPath: "recipient@example.com"))

        if case .accepted(let response, let newState) = result {
            #expect(newState == .recipient)
            #expect(response.code == .okay)
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.state == .recipient)
        #expect(sm.currentTransaction()?.recipients.count == 1)
        #expect(sm.currentTransaction()?.recipients.first == "recipient@example.com")
    }

    @Test("Multiple RCPT TO commands")
    func testMultipleRcpt() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        _ = sm.process(.mailFrom(reversePath: "sender@example.com"))
        _ = sm.process(.rcptTo(forwardPath: "user1@example.com"))
        _ = sm.process(.rcptTo(forwardPath: "user2@example.com"))
        _ = sm.process(.rcptTo(forwardPath: "user3@example.com"))

        #expect(sm.state == .recipient)
        #expect(sm.currentTransaction()?.recipients.count == 3)
    }

    @Test("RCPT TO before MAIL FROM rejected")
    func testRcptBeforeMail() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        let result = sm.process(.rcptTo(forwardPath: "recipient@example.com"))

        if case .rejected(let response) = result {
            #expect(response.code == .badSequence)
        } else {
            Issue.record("Expected rejection")
        }

        #expect(sm.state == .greeted)
    }

    // MARK: - DATA

    @Test("DATA after RCPT TO")
    func testData() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        _ = sm.process(.mailFrom(reversePath: "sender@example.com"))
        _ = sm.process(.rcptTo(forwardPath: "recipient@example.com"))

        let result = sm.process(.data)

        if case .accepted(let response, let newState) = result {
            #expect(newState == .data)
            #expect(response.code == .startMailInput)
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.state == .data)
    }

    @Test("DATA before RCPT TO rejected")
    func testDataBeforeRcpt() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        _ = sm.process(.mailFrom(reversePath: "sender@example.com"))

        let result = sm.process(.data)

        if case .rejected(let response) = result {
            #expect(response.code == .badSequence)
        } else {
            Issue.record("Expected rejection")
        }

        #expect(sm.state == .mail)
    }

    @Test("Complete DATA transfers to greeted")
    func testCompleteData() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        _ = sm.process(.mailFrom(reversePath: "sender@example.com"))
        _ = sm.process(.rcptTo(forwardPath: "recipient@example.com"))
        _ = sm.process(.data)

        let messageData = Data("Subject: Test\r\n\r\nHello World\r\n".utf8)
        let result = sm.completeData(messageData: messageData)

        if case .accepted(let response, let newState) = result {
            #expect(newState == .greeted)
            #expect(response.code == .okay)
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.state == .greeted)
        #expect(sm.currentTransaction() == nil)  // Transaction cleared
    }

    // MARK: - RSET

    @Test("RSET resets transaction")
    func testRset() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        _ = sm.process(.mailFrom(reversePath: "sender@example.com"))
        _ = sm.process(.rcptTo(forwardPath: "recipient@example.com"))

        #expect(sm.currentTransaction() != nil)

        let result = sm.process(.reset)

        if case .accepted(let response, let newState) = result {
            #expect(newState == .greeted)
            #expect(response.code == .okay)
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.state == .greeted)
        #expect(sm.currentTransaction() == nil)
    }

    // MARK: - NOOP

    @Test("NOOP does not change state")
    func testNoop() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))
        _ = sm.process(.mailFrom(reversePath: "sender@example.com"))

        let result = sm.process(.noop)

        if case .accepted(let response, let newState) = result {
            #expect(newState == .mail)
            #expect(response.code == .okay)
        } else {
            Issue.record("Expected accepted")
        }

        #expect(sm.state == .mail)
    }

    // MARK: - QUIT

    @Test("QUIT closes session")
    func testQuit() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.helo(domain: "client"))

        let result = sm.process(.quit)

        if case .close(let response) = result {
            #expect(response.code == .serviceClosing)
        } else {
            Issue.record("Expected close")
        }

        #expect(sm.state == .quit)
    }

    @Test("Commands after QUIT are rejected")
    func testAfterQuit() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        _ = sm.process(.quit)

        let result = sm.process(.helo(domain: "client"))

        if case .rejected = result {
            // Expected
        } else {
            Issue.record("Expected rejection after QUIT")
        }
    }

    // MARK: - Full Conversation

    @Test("Complete SMTP conversation")
    func testCompleteConversation() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        // EHLO
        if case .accepted(_, let state) = sm.process(.ehlo(domain: "client")) {
            #expect(state == .greeted)
        }

        // MAIL FROM
        if case .accepted(_, let state) = sm.process(.mailFrom(reversePath: "sender@test.com")) {
            #expect(state == .mail)
        }

        // RCPT TO (multiple)
        _ = sm.process(.rcptTo(forwardPath: "user1@test.com"))
        if case .accepted(_, let state) = sm.process(.rcptTo(forwardPath: "user2@test.com")) {
            #expect(state == .recipient)
        }

        // DATA
        if case .accepted(_, let state) = sm.process(.data) {
            #expect(state == .data)
        }

        // Complete data
        let msg = Data("Test message".utf8)
        if case .accepted(_, let state) = sm.completeData(messageData: msg) {
            #expect(state == .greeted)
        }

        // Can send another message
        _ = sm.process(.mailFrom(reversePath: "sender2@test.com"))
        #expect(sm.state == .mail)

        // QUIT
        if case .close = sm.process(.quit) {
            #expect(sm.state == .quit)
        }
    }

    // MARK: - Error Cases

    @Test("Unknown command rejected")
    func testUnknownCommand() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        let result = sm.process(.unknown(command: "EXPN"))

        if case .rejected(let response) = result {
            #expect(response.code == .syntaxError)
        } else {
            Issue.record("Expected rejection")
        }
    }

    @Test("VRFY command not implemented")
    func testVrfyNotImplemented() {
        var sm = SMTPStateMachine(domain: "mail.example.com")

        let result = sm.process(.verify(address: "user@example.com"))

        if case .rejected(let response) = result {
            #expect(response.code == .commandNotImplemented)
        } else {
            Issue.record("Expected rejection")
        }
    }
}
