// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudeGPTLauncher",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClaudeGPTLauncher", targets: ["ClaudeGPTLauncher"]),
        .executable(name: "ClaudeGPTMCP", targets: ["ClaudeGPTMCP"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeGPTLauncher",
            path: "Sources/ClaudeGPTLauncher"
        ),
        .executableTarget(
            name: "ClaudeGPTMCP",
            path: "Sources/ClaudeGPTMCP"
        ),
        .testTarget(
            name: "ClaudeGPTLauncherTests",
            dependencies: ["ClaudeGPTLauncher", "ClaudeGPTMCP"]
        )
    ]
)
