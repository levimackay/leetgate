// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "leetgate",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "LeetgateCore"),
        .target(name: "LeetgateSync", dependencies: ["LeetgateCore"]),
        .executableTarget(name: "leetgated", dependencies: ["LeetgateCore", "LeetgateSync"]),
        .executableTarget(name: "leetgate", dependencies: ["LeetgateCore"]),
        .testTarget(name: "LeetgateCoreTests", dependencies: ["LeetgateCore"]),
        .testTarget(name: "LeetgateSyncTests", dependencies: ["LeetgateSync"]),
    ]
)
