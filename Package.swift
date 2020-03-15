// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Xoodyak",
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
            dependencies: ["Xoodyak"]),
    ]
)
