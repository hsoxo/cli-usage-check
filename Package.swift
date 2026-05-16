// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIUsageCheck",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AIUsageCheck", targets: ["AIUsageCheck"])
    ],
    targets: [
        .executableTarget(
            name: "AIUsageCheck",
            path: "Sources/AIUsageCheck"
        )
    ]
)
