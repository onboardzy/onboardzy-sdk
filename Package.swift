// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Onboardzy",
    platforms: [
        .iOS(.v14) // Ensures compatibility with iOS 13+
    ],
    products: [
        .library(
            name: "Onboardzy",
            targets: ["Onboardzy"]
        ),
    ],
    targets: [
        .target(
            name: "Onboardzy",
            path: "Sources/Onboardzy"
        ),
        .testTarget(
            name: "OnboardzyTests",
            dependencies: ["Onboardzy"]
        ),
    ]
)
