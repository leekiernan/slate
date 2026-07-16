// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Slate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SlateCore", targets: ["SlateCore"]),
        .library(name: "SlateMacOS", targets: ["SlateMacOS"]),
        .executable(name: "Slate", targets: ["SlateApp"])
    ],
    targets: [
        .target(name: "SlateCore"),
        .target(
            name: "SlateMacOS",
            dependencies: ["SlateCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .executableTarget(
            name: "SlateApp",
            dependencies: ["SlateCore", "SlateMacOS"]
        ),
        .testTarget(
            name: "SlateCoreTests",
            dependencies: ["SlateCore"]
        )
    ]
)
