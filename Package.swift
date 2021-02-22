// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "xoodyak-swift",
    products: [
        .library(
            name: "Xoodyak",
            targets: ["Xoodyak"]),
    ],
    targets: [
        .target(
            name: "Xoodoo"),
        .target(
            name: "Xoodyak",
            dependencies: ["Xoodoo"]),
        .testTarget(
            name: "XoodooTests",
            dependencies: ["Xoodoo"]),
        .testTarget(
            name: "XoodyakTests",
            dependencies: ["Xoodyak"],
            resources: [
                .copy("Resources/aead.json"),
                .copy("Resources/hash.json")
            ])
    ]
)
