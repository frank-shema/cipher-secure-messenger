// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CipherNetworking",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CipherNetworking", targets: ["CipherNetworking"])
    ],
    dependencies: [
        .package(path: "../CipherCore")
    ],
    targets: [
        .target(
            name: "CipherNetworking",
            dependencies: [
                .product(name: "CipherCore", package: "CipherCore")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CipherNetworkingTests",
            dependencies: ["CipherNetworking"]
        )
    ],
    swiftLanguageModes: [.v6]
)
