// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Account",
    platforms: [.iOS(.v18), .visionOS(.v1), .macCatalyst(.v18)],
    products: [.library(name: "Account", targets: ["Account"])],
    dependencies: [
        .package(path: "../Models"),
        .package(path: "../MemoData"),
        .package(path: "../DesignSystem"),
        .package(path: "../Env"),
        .package(url: "https://github.com/hmlongco/Factory", from: "2.5.3")
    ],
    targets: [
        .target(name: "Account", dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "MemoData", package: "MemoData"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Env", package: "Env"),
                .product(name: "Factory", package: "Factory")
        ])
    ]
)
