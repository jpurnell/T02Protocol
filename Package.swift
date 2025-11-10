// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "T02Protocol",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Library for T02 protocol
        .library(
            name: "T02Protocol",
            targets: ["T02Protocol"]),

        // Command-line tool for testing
        .executable(
            name: "T02PrintTool",
            targets: ["T02PrintTool"]),
    ],
    dependencies: [
        // Swift Testing is now built into Swift 6+ toolchain
    ],
    targets: [
        // Main T02 protocol implementation
        .target(
            name: "T02Protocol",
            dependencies: [],
            resources: [
                // Include any resources needed
            ]
        ),

        // Command-line tool for hardware testing
        .executableTarget(
            name: "T02PrintTool",
            dependencies: ["T02Protocol"],
            linkerSettings: [
                .linkedFramework("IOBluetooth", .when(platforms: [.macOS])),
                .linkedFramework("CoreBluetooth", .when(platforms: [.macOS]))
            ]
        ),

        // Tests using Swift Testing (built into Swift 6+)
        .testTarget(
            name: "T02ProtocolTests",
            dependencies: [
                "T02Protocol",
            ],
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
