// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlowState",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FlowState", targets: ["FlowState"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "FlowState",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            // Standard layout: Sources/FlowState
            path: "Sources/FlowState"
        )
    ]
)
