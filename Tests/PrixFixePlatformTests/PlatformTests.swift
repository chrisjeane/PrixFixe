import Testing
@testable import PrixFixePlatform

@Suite("Platform Detection Tests")
struct PlatformTests {
    @Test("Platform detection returns a valid platform")
    func testPlatformDetection() {
        let platform = Platform.current
        // Should be one of the supported platforms
        #expect([Platform.linux, Platform.macOS, Platform.iOS].contains(platform))
    }

    @Test("Platform capabilities are available")
    func testPlatformCapabilities() {
        let capabilities = PlatformCapabilities.current

        // Verify capabilities make sense for detected platform
        switch Platform.current {
        case .linux:
            #expect(!capabilities.hasNetworkFramework)
            #expect(!capabilities.hasBackgroundLimitations)
            #expect(capabilities.recommendedMaxConnections >= 100)

        case .macOS:
            #expect(capabilities.hasNetworkFramework)
            #expect(!capabilities.hasBackgroundLimitations)
            #expect(capabilities.recommendedMaxConnections >= 100)

        case .iOS:
            #expect(capabilities.hasNetworkFramework)
            #expect(capabilities.hasBackgroundLimitations)
            #expect(capabilities.recommendedMaxConnections > 0)
        }
    }
}
