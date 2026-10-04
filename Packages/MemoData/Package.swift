// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoData",
    platforms: [.iOS(.v18), .visionOS(.v1), .macCatalyst(.v18)],
    products: [.library(name: "MemoData", targets: ["MemoData"])],
    dependencies: [
        .package(path: "../Models"),
        .package(path: "../Services"),
        .package(url: "https://github.com/hmlongco/Factory", from: "2.5.3"),
        .package(url: "https://github.com/evgenyneu/keychain-swift", from: "21.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .target(name: "MemoData", dependencies: [
                .product(name: "Models", package: "Models"),
                .product(name: "MemosV0Service", package: "Services"),
                .product(name: "MemosV1Service", package: "Services"),
                .product(name: "Factory", package: "Factory"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
        ]),
        .testTarget(name: "MemoDataTests", dependencies: ["MemoData"], resources: [.copy("Fixtures")])
    ]
)
