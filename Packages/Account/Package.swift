// swift-tools-version: 5.9
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
        .package(url: "https://github.com/evgenyneu/keychain-swift", from: "20.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Account",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "KeychainSwift", package: "keychain-swift")
            ]
        ),
        .testTarget(
            name: "AccountTests",
            dependencies: ["Account"]),
    ]
)
