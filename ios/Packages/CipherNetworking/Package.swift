// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CipherNetworking",
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
            ]
        ),
        .testTarget(
            name: "CipherNetworkingTests",
            dependencies: ["CipherNetworking"]
        )
    ],
    swiftLanguageModes: [.v6]
)
