// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CB21",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CB21Core", targets: ["CB21Core"]),
    ],
    targets: [
        .target(
            name: "CB21Core",
            swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
        ),
        .testTarget(
            name: "CB21CoreTests",
            dependencies: ["CB21Core"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
