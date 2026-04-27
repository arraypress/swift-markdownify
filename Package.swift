// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Markdownify",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Markdownify",
            targets: ["Markdownify"]
        ),
    ],
    targets: [
        .target(
            name: "Markdownify",
            dependencies: [],
            exclude: [
                "Resources/JS/LICENSES.md"
            ],
            resources: [
                .copy("Resources/JS/Readability.js"),
                .copy("Resources/JS/turndown.js"),
                .copy("Resources/JS/turndown-plugin-gfm.js"),
                .copy("Resources/JS/bridge.js")
            ]
        ),
        .testTarget(
            name: "MarkdownifyTests",
            dependencies: ["Markdownify"],
            resources: [
                .process("Fixtures")
            ]
        ),
    ]
)
