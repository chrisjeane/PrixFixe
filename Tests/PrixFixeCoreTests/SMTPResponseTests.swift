import Testing
import Foundation
@testable import PrixFixeCore

@Suite("SMTP Response Tests")
struct SMTPResponseTests {

    @Test("Format single-line response")
    func testSingleLineResponse() {
        let response = SMTPResponse(code: .okay, message: "OK")
        #expect(response.formatted() == "250 OK\r\n")
    }

    @Test("Format greeting response")
    func testServiceReady() {
        let response = SMTPResponse.serviceReady(domain: "mail.example.com")
        #expect(response.code == .serviceReady)
        #expect(response.formatted() == "220 mail.example.com ESMTP Service ready\r\n")
    }

    @Test("Format closing response")
    func testClosing() {
        let response = SMTPResponse.closing(domain: "mail.example.com")
        #expect(response.code == .serviceClosing)
        #expect(response.formatted().starts(with: "221"))
    }

    @Test("Format multiline response")
    func testMultilineResponse() {
        let response = SMTPResponse(code: .okay, lines: [
            "mail.example.com Hello",
            "SIZE 10485760",
            "8BITMIME"
        ])

        let formatted = response.formatted()
        #expect(formatted.contains("250-mail.example.com Hello\r\n"))
        #expect(formatted.contains("250-SIZE 10485760\r\n"))
        #expect(formatted.contains("250 8BITMIME\r\n"))
    }

    @Test("EHLO response with capabilities")
    func testEhloResponse() {
        let response = SMTPResponse.ehlo(domain: "mail.example.com", capabilities: [
            "SIZE 10485760",
            "8BITMIME",
            "PIPELINING"
        ])

        let formatted = response.formatted()
        #expect(formatted.contains("250-mail.example.com Hello\r\n"))
        #expect(formatted.contains("250-SIZE 10485760\r\n"))
        #expect(formatted.contains("250-8BITMIME\r\n"))
        #expect(formatted.contains("250 PIPELINING\r\n"))
    }

    @Test("Start mail input response")
    func testStartMailInput() {
        let response = SMTPResponse.startMailInput
        #expect(response.code == .startMailInput)
        #expect(response.formatted() == "354 Start mail input; end with <CRLF>.<CRLF>\r\n")
    }

    @Test("Error responses")
    func testErrorResponses() {
        let syntaxError = SMTPResponse.syntaxError()
        #expect(syntaxError.code == .syntaxError)
        #expect(syntaxError.code.isError)
        #expect(syntaxError.code.isPermanent)

        let badSequence = SMTPResponse.badSequence()
        #expect(badSequence.code == .badSequence)
        #expect(badSequence.code.isError)
    }

    @Test("Response code properties")
    func testResponseCodeProperties() {
        #expect(SMTPResponseCode.okay.isPositive)
        #expect(!SMTPResponseCode.okay.isError)

        #expect(SMTPResponseCode.startMailInput.isPositive)

        #expect(SMTPResponseCode.mailboxBusy.isError)
        #expect(SMTPResponseCode.mailboxBusy.isTransient)
        #expect(!SMTPResponseCode.mailboxBusy.isPermanent)

        #expect(SMTPResponseCode.syntaxError.isError)
        #expect(SMTPResponseCode.syntaxError.isPermanent)
        #expect(!SMTPResponseCode.syntaxError.isTransient)
    }

    @Test("Convert response to Data")
    func testResponseToData() {
        let response = SMTPResponse.ok("Message accepted")
        let data = response.data()

        let string = String(data: data, encoding: .utf8)
        #expect(string == "250 Message accepted\r\n")
    }

    @Test("Not implemented response")
    func testNotImplemented() {
        let response = SMTPResponse.notImplemented("EXPN")
        #expect(response.code == .commandNotImplemented)
        #expect(response.formatted().contains("EXPN"))
    }
}
