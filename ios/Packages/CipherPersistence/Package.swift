// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CipherPersistence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CipherPersistence", targets: ["CipherPersistence"])
    ],
    dependencies: [
        .package(path: "../CipherCore")
    ],
    targets: [
        .target(
            name: "CipherPersistence",
            dependencies: [
                .product(name: "CipherCore", package: "CipherCore")
            ]
        ),
        .testTarget(
            name: "CipherPersistenceTests",
            dependencies: ["CipherPersistence"]
        )
    ],
    swiftLanguageModes: [.v6]
)
