// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CipherCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CipherCore", targets: ["CipherCore"])
    ],
    targets: [
        .target(
            name: "CipherCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CipherCoreTests",
            dependencies: ["CipherCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
