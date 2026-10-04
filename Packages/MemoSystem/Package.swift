// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoSystem",
    platforms: [.iOS(.v18), .visionOS(.v1), .macCatalyst(.v18)],
    products: [.library(name: "MemoSystem", targets: ["MemoSystem"])],
    dependencies: [
        .package(path: "../Models"),
        .package(path: "../MemoData")
    ],
    targets: [
        .target(name: "MemoSystem", dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "MemoData", package: "MemoData")
        ]),
        .testTarget(name: "MemoSystemTests", dependencies: ["MemoSystem", "MemoData"])
    ]
)
