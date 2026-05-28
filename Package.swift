// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ConveltKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "ConveltKit",
            targets: ["ConveltKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "ConveltKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            path: "Sources/ConveltKit"
        ),
        .testTarget(
            name: "ConveltKitTests",
            dependencies: ["ConveltKit"],
            path: "Tests/ConveltKitTests"
        ),
    ]
)
