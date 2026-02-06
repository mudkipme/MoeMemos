// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MemoKit",
    platforms: [
      .iOS(.v17),
      .visionOS(.v1),
      .macCatalyst(.v17),
    ],
    products: [
        .library(
            name: "MemoKit",
            targets: ["MemoKit"]
        ),
    ],
    dependencies: [
        .package(name: "Models", path: "../Models"),
        .package(name: "Account", path: "../Account"),
        .package(name: "DesignSystem", path: "../DesignSystem"),
        .package(url: "https://github.com/hmlongco/Factory", from: "2.5.3"),
    ],
    targets: [
        .target(
            name: "MemoKit",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "Account", package: "Account"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Factory", package: "Factory"),
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "MemoKitTests",
            dependencies: ["MemoKit"],
            path: "Tests/MemoKitTests"
        ),
    ]
)
