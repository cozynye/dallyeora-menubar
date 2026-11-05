// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dallyeora",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DallyeoraCore"),
        .executableTarget(name: "Dallyeora", dependencies: ["DallyeoraCore"]),
        .testTarget(name: "DallyeoraCoreTests", dependencies: ["DallyeoraCore"]),
    ]
)
