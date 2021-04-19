// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "xoodyak-swift",
    products: [
        .library(
            name: "Xoodyak",
            targets: ["Xoodyak"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nixberg/hexstring-swift", from: "0.1.0"),
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
            dependencies: [
                .product(name: "HexString", package: "hexstring-swift"),
                "Xoodyak",
            ],
            resources: [
                .copy("Resources/aead.json"),
                .copy("Resources/hash.json")
            ])
    ]
)
