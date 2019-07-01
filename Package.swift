// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Xoodyak",
    products: [
        .library(
            name: "Xoodyak",
            targets: ["Xoodyak"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nixberg/Xoodoo", .branch("master")),
        .package(url: "https://github.com/jedisct1/swift-sodium", from: "0.8.0"),
    ],
    targets: [
        .target(
            name: "Xoodyak",
            dependencies: ["Xoodoo"]),
        .testTarget(
            name: "XoodyakTests",
            dependencies: ["Xoodyak", "Sodium"]),
    ]
)
