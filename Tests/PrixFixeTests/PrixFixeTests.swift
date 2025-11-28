import Testing
@testable import PrixFixe

@Suite("PrixFixe API Tests")
struct PrixFixeTests {
    @Test("ServerConfiguration default values")
    func testServerConfigurationDefaults() {
        let config = ServerConfiguration.default

        #expect(config.domain == "localhost")
        #expect(config.port == 2525)
        #expect(config.maxConnections == 100)
        #expect(config.maxMessageSize == 10 * 1024 * 1024)
        #expect(config.listenBacklog == 256)
    }

    @Test("ServerConfiguration custom initialization")
    func testServerConfigurationCustom() {
        let config = ServerConfiguration(
            domain: "mail.example.com",
            port: 8025,
            maxConnections: 50,
            maxMessageSize: 5 * 1024 * 1024,
            listenBacklog: 128,
            tlsConfiguration: nil
        )

        #expect(config.domain == "mail.example.com")
        #expect(config.port == 8025)
        #expect(config.maxConnections == 50)
        #expect(config.maxMessageSize == 5 * 1024 * 1024)
        #expect(config.listenBacklog == 128)
        #expect(config.tlsConfiguration == nil)
    }
}
