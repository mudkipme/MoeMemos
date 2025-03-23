// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Models",
    platforms: [
      .iOS(.v18),
      .visionOS(.v2),
      .macCatalyst(.v18),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Models",
            targets: ["Models"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory", from: "2.3.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Models",
            dependencies: [
                .product(name: "Factory", package: "Factory")
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ModelsTests",
            dependencies: ["Models"]),
    ]
)
