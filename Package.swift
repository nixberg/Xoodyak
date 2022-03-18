// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "xoodyak-swift",
    products: [
        .library(
            name: "Xoodyak",
            targets: ["Xoodyak"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nixberg/crypto-traits-swift", from: "0.2.0"),
        .package(url: "https://github.com/nixberg/endianbytes-swift", from: "0.4.0"),
        .package(url: "https://github.com/nixberg/hexstring-swift", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "Xoodoo",
            dependencies: [
                .product(name: "EndianBytes", package: "endianbytes-swift"),
            ]),
        .target(
            name: "Xoodyak",
            dependencies: [
                .product(name: "Duplex", package: "crypto-traits-swift"),
                "Xoodoo"
            ]),
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
