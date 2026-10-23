// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacVideoLoader",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacVideoLoader",
            targets: ["MacVideoLoader"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacVideoLoader",
            dependencies: [],
            path: "Sources/MacVideoLoader"
        ),
    ]
)
