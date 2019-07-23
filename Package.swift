// swift-tools-version:5.1

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
    ],
    targets: [
        .target(
            name: "Xoodyak",
            dependencies: ["Xoodoo"]),
        .testTarget(
            name: "XoodyakTests",
            dependencies: ["Xoodyak"]),
    ]
)
