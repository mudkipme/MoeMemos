// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Account",
    platforms: [
      .iOS(.v17),
      .visionOS(.v1),
      .macCatalyst(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Account",
            targets: ["Account"]),
    ],
    dependencies: [
        .package(name: "Models", path: "../Models"),
        .package(name: "Services", path: "../Services"),
        .package(name: "DesignSystem", path: "../DesignSystem"),
        .package(name: "Env", path: "../Env"),
        .package(url: "https://github.com/evgenyneu/keychain-swift", from: "21.0.0"),
        .package(url: "https://github.com/hmlongco/Factory", from: "2.3.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Account",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "MemosV0Service", package: "Services"),
                .product(name: "MemosV1Service", package: "Services"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Env", package: "Env"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "Factory", package: "Factory")
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "AccountTests",
            dependencies: ["Account"]),
    ]
)
