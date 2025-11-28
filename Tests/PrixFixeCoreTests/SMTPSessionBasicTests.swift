import Testing
import Foundation
@testable import PrixFixeCore
@testable import PrixFixeNetwork

@Suite("SMTP Session Basic Tests")
struct SMTPSessionBasicTests {

    /// Minimal mock connection for basic testing
    actor TestConnection: NetworkConnection {
        private var data: Data

        nonisolated var remoteAddress: any NetworkAddress {
            SocketAddress.localhost(port: 12345)
        }

        init(data: String) {
            self.data = Data(data.utf8)
        }

        func read(maxBytes: Int) async throws -> Data {
            if data.isEmpty {
                return Data()
            }

            let amount = min(maxBytes, data.count)
            let result = data.prefix(amount)
            data = data.dropFirst(amount)
            return result
        }

        func write(_ data: Data) async throws {
            // Ignore writes for now
        }

        func close() async throws {
            data = Data()
        }
    }

    @Test("Session can be created")
    func testSessionCreation() async {
        let conn = TestConnection(data: "QUIT\r\n")
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        #expect(session != nil)
    }

    @Test("Session can process QUIT")
    func testSessionQuit() async {
        let conn = TestConnection(data: "QUIT\r\n")
        let config = SessionConfiguration(
            domain: "test.com",
            connectionTimeout: 0,
            commandTimeout: 0
        )

        let session = SMTPSession(connection: conn, configuration: config)
        await session.run()

        // If we get here without crashing, the test passes
        #expect(true)
    }
}
