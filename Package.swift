// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "haunts",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "haunts", path: "Sources/haunts")
    ]
)
