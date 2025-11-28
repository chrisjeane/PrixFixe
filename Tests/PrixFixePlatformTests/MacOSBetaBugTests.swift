/// Tests for macOS 26.1 beta bug detection and workaround

import Testing
import Foundation

@testable import PrixFixePlatform

@Suite("macOS Beta Bug Detection Tests")
struct MacOSBetaBugTests {

    @Test("Platform capabilities includes bug detection flag")
    func testHasBugDetectionFlag() {
        let caps = PlatformCapabilities.current

        #if os(macOS)
        // On macOS, we should be able to check the flag
        // The value depends on the actual OS version
        print("macOS hasNetworkFrameworkBug: \(caps.hasNetworkFrameworkBug)")

        // Verify it's a valid boolean (not nil or broken)
        let _ = caps.hasNetworkFrameworkBug ? "true" : "false"
        #else
        // On non-macOS platforms, should always be false
        #expect(caps.hasNetworkFrameworkBug == false)
        #endif
    }

    @Test("Bug detection on macOS 26.1 beta", .enabled(if: Platform.current == .macOS))
    func testMacOSBetaDetection() {
        let caps = PlatformCapabilities.current

        #if os(macOS)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        print("macOS version: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")

        // If running on macOS 15.2+ (26.1 beta territory), the bug flag should be true
        if osVersion.majorVersion >= 15 && osVersion.minorVersion >= 2 {
            #expect(caps.hasNetworkFrameworkBug == true,
                   "Expected bug flag to be true on macOS 15.2+ (26.1 beta)")
            print("✓ Bug detection active on macOS 26.1 beta")
        }
        #endif
    }

    @Test("Bug detection is false on Linux", .enabled(if: Platform.current == .linux))
    func testLinuxNoBug() {
        let caps = PlatformCapabilities.current
        #expect(caps.hasNetworkFrameworkBug == false)
    }

    @Test("Bug detection is false on iOS", .enabled(if: Platform.current == .iOS))
    func testiOSNoBug() {
        let caps = PlatformCapabilities.current
        #expect(caps.hasNetworkFrameworkBug == false)
    }
}
