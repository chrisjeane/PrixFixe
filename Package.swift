// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PrixFixe",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
        // Linux is implicitly supported
    ],
    products: [
        // Main library product - re-exports all public APIs
        .library(
            name: "PrixFixe",
            targets: ["PrixFixe"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
    ],
    targets: [
        // MARK: - Main Module (Re-exports)

        .target(
            name: "PrixFixe",
            dependencies: [
                "PrixFixeCore",
                "PrixFixeNetwork",
                "PrixFixeMessage",
                "PrixFixePlatform"
            ],
            swiftSettings: [
                .enableExperimentalFeature("AccessLevelOnImport")
            ]
        ),

        // MARK: - Core Modules

        /// Networking abstractions and platform-specific implementations
        .target(
            name: "PrixFixeNetwork",
            dependencies: ["PrixFixePlatform"]
        ),

        /// SMTP protocol implementation (state machine, parser, formatter)
        .target(
            name: "PrixFixeCore",
            dependencies: [
                "PrixFixeNetwork",
                "PrixFixeMessage"
            ]
        ),

        /// Message handling and email structure
        .target(
            name: "PrixFixeMessage",
            dependencies: []
        ),

        /// Platform detection and capabilities
        .target(
            name: "PrixFixePlatform",
            dependencies: []
        ),

        // MARK: - Test Targets

        .testTarget(
            name: "PrixFixeTests",
            dependencies: [
                "PrixFixe",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),

        .testTarget(
            name: "PrixFixeNetworkTests",
            dependencies: [
                "PrixFixeNetwork",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),

        .testTarget(
            name: "PrixFixeCoreTests",
            dependencies: [
                "PrixFixeCore",
                "PrixFixeNetwork",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),

        .testTarget(
            name: "PrixFixeMessageTests",
            dependencies: [
                "PrixFixeMessage",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),

        .testTarget(
            name: "PrixFixePlatformTests",
            dependencies: [
                "PrixFixePlatform",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),

        .testTarget(
            name: "PrixFixeIntegrationTests",
            dependencies: [
                "PrixFixe",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
    ]
)
