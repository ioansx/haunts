// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ismux",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ismux", path: "Sources/ismux")
    ]
)
