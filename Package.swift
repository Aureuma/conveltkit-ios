// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ConveltKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "ConveltKit",
            targets: ["ConveltKit"]
        )
    ],
    targets: [
        .target(
            name: "ConveltKit",
            path: "Sources/ConveltKit"
        ),
        .testTarget(
            name: "ConveltKitTests",
            dependencies: ["ConveltKit"],
            path: "Tests/ConveltKitTests"
        ),
    ]
)
