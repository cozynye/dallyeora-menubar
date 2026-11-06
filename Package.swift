// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dallyeora",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DallyeoraCore"),
        .executableTarget(name: "Dallyeora", dependencies: ["DallyeoraCore"]),
        // 빌드 때 앱 아이콘(.icns)을 만든다. scripts/make-app.sh가 부른다.
        .executableTarget(name: "IconTool", dependencies: ["DallyeoraCore"]),
        .testTarget(name: "DallyeoraCoreTests", dependencies: ["DallyeoraCore"]),
    ]
)
