// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppleOrchestratorAI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AppleOrchestratorAI", targets: ["AppleOrchestratorAI"])
    ],
    targets: [
        .executableTarget(
            name: "AppleOrchestratorAI"
        )
    ]
)
