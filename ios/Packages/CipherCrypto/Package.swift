// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CipherCrypto",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CipherCrypto", targets: ["CipherCrypto"])
    ],
    dependencies: [
        .package(path: "../CipherCore")
    ],
    targets: [
        .target(
            name: "CipherCrypto",
            dependencies: [
                .product(name: "CipherCore", package: "CipherCore")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CipherCryptoTests",
            dependencies: ["CipherCrypto"]
        )
    ],
    swiftLanguageModes: [.v6]
)
