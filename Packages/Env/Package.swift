// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Env",
    platforms: [
      .iOS(.v17),
      .visionOS(.v1),
      .macCatalyst(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Env",
            targets: ["Env"]),
    ],
    dependencies: [
        .package(name: "Models", path: "../Models"),
        .package(url: "https://github.com/hmlongco/Factory", from: "2.3.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Env",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "Factory", package: "Factory")
            ]
        ),
        .testTarget(
            name: "EnvTests",
            dependencies: ["Env"]),
    ]
)
