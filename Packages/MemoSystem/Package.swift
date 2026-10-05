// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoSystem",
    platforms: [.iOS(.v18), .visionOS(.v1), .macCatalyst(.v18)],
    // Xcode statically links this product and merges its App Intents metadata into
    // each host. Do not add AppIntentsPackage/includedPackages for this library:
    // that adds a runtime package lookup that can fail in stripped Release builds.
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
