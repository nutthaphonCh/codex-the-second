// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexTheSecond",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "CodexTheSecond", targets: ["CodexTheSecond"]),
        .executable(name: "c2nd", targets: ["c2nd"]),
        .library(name: "CodexTheSecondCore", targets: ["CodexTheSecondCore"]),
    ],
    targets: [
        .target(name: "CodexTheSecondCore"),
        .executableTarget(
            name: "CodexTheSecond",
            dependencies: ["CodexTheSecondCore"]
        ),
        .executableTarget(
            name: "c2nd",
            dependencies: ["CodexTheSecondCore"]
        ),
        .testTarget(
            name: "CodexTheSecondCoreTests",
            dependencies: ["CodexTheSecondCore"]
        ),
    ]
)
