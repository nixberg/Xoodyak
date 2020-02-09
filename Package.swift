// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Xoodyak",
    products: [
        .library(
            name: "Xoodyak",
            targets: ["Xoodyak"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Xoodoo",
            dependencies: []),
        .target(
            name: "Xoodyak",
            dependencies: ["Xoodoo"]),
        .testTarget(
            name: "XoodooTests",
            dependencies: ["Xoodoo"]),
        .testTarget(
            name: "XoodyakTests",
            dependencies: ["Xoodyak"]),
    ]
)
