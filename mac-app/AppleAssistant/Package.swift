// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppleAssistant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AppleAssistant", targets: ["AppleAssistant"])
    ],
    targets: [
        .executableTarget(
            name: "AppleAssistant",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/AppleAssistant/Info.plist"
                ])
            ]
        )
    ]
)
