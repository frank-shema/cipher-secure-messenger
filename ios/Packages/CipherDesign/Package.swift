// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CipherDesign",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CipherDesign", targets: ["CipherDesign"])
    ],
    targets: [
        .target(name: "CipherDesign"),
        .testTarget(
            name: "CipherDesignTests",
            dependencies: ["CipherDesign"]
        )
    ],
    swiftLanguageModes: [.v6]
)
