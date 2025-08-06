// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "NostrAPITest",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/nostr-sdk/nostr-sdk-ios.git", exact: "0.3.0")
    ],
    targets: [
        .executableTarget(
            name: "NostrAPITest",
            dependencies: [
                .product(name: "NostrSDK", package: "nostr-sdk-ios")
            ]
        )
    ]
)