// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MarkdownPlugin",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/lagueux/tc4mac-plugin-sdk.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "MarkdownPlugin",
            dependencies: [.product(name: "TCPluginSDK", package: "tc4mac-plugin-sdk")]),
        .testTarget(name: "MarkdownPluginTests", dependencies: ["MarkdownPlugin"])
    ]
)
