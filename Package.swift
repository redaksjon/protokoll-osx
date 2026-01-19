// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Protokoll",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Protokoll",
            targets: ["Protokoll"]
        ),
        .library(
            name: "ProtokolLib",
            targets: ["ProtokolLib"]
        )
    ],
    targets: [
        // Core library with MCP client and types (testable)
        .target(
            name: "ProtokolLib",
            path: "Sources/ProtokolLib"
        ),
        // Main application executable
        .executableTarget(
            name: "Protokoll",
            dependencies: ["ProtokolLib"],
            path: "Sources/ProtokolApp"
        ),
        // Test target
        .testTarget(
            name: "ProtokolTests",
            dependencies: ["ProtokolLib"],
            path: "Tests/ProtokolTests"
        )
    ]
)
