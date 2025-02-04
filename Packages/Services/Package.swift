// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Services",
    platforms: [
      .iOS(.v17),
      .visionOS(.v1),
      .macCatalyst(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MemosV0Service",
            targets: ["MemosV0Service"]),
        .library(
            name: "MemosV1Service",
            targets: ["MemosV1Service"]),
        .library(
            name: "BlinkoV1Service",
            targets: ["BlinkoV1Service"]),
    ],
    dependencies: [
        .package(name: "Models", path: "../Models"),
        .package(url: "https://github.com/apple/swift-openapi-generator", .upToNextMinor(from: "1.7.0")),
        .package(url: "https://github.com/apple/swift-openapi-runtime", .upToNextMinor(from: "1.8.0")),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", .upToNextMinor(from: "1.0.2")),
        .package(url: "https://github.com/nodes-vapor/data-uri", from: "2.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ServiceUtils",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "Models", package: "Models"),
                .product(name: "DataURI", package: "data-uri"),
            ]
        ),
        .target(
            name: "MemosV0Service",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                "ServiceUtils"
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .target(
            name: "MemosV1Service",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                "ServiceUtils"
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .target(
            name: "BlinkoV1Service",
            dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                "ServiceUtils"
            ],
            swiftSettings: [
              .enableExperimentalFeature("StrictConcurrency"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
    ]
)
