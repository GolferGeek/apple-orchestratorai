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
            name: "AppleOrchestratorAI",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/AppleOrchestratorAI/Info.plist"
                ])
            ]
        )
    ]
)
