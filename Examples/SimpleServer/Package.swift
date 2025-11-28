// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimpleServer",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    dependencies: [
        .package(name: "PrixFixe", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "SimpleServer",
            dependencies: ["PrixFixe"],
            path: ".",
            linkerSettings: [
                // Link OpenSSL on Linux for TLS support
                .linkedLibrary("ssl", .when(platforms: [.linux])),
                .linkedLibrary("crypto", .when(platforms: [.linux]))
            ]
        )
    ]
)
