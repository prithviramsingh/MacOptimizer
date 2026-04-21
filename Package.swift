// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOptimizer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacOptimizer",
            path: "Sources/MacOptimizer"
        )
    ]
)
