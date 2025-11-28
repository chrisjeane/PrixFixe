import Testing
import Foundation
@testable import PrixFixeMessage

@Suite("Email Message Tests")
struct EmailMessageTests {
    @Test("EmailAddress initialization")
    func testEmailAddressInit() {
        let address = EmailAddress("test@example.com")
        #expect(address.address == "test@example.com")
        #expect(address.description == "test@example.com")
    }

    @Test("EmailMessage initialization")
    func testEmailMessageInit() {
        let from = EmailAddress("sender@example.com")
        let recipients = [EmailAddress("recipient@example.com")]
        let data = Data("Test message".utf8)

        let message = EmailMessage(from: from, recipients: recipients, data: data)

        #expect(message.from == from)
        #expect(message.recipients == recipients)
        #expect(message.data == data)
    }
}
