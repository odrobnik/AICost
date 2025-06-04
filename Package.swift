// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenAICost",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "openai-cost", targets: ["OpenAICostCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "OpenAICost",
            dependencies: []
        ),
        .executableTarget(
            name: "OpenAICostCLI",
            dependencies: [
                "OpenAICost",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "OpenAICostTests",
            dependencies: ["OpenAICost"]
        )
    ]
) 