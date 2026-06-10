// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "a2a-swift",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "A2A", targets: ["A2A"]),
        .library(name: "A2AClient", targets: ["A2AClient"]),
        .library(name: "A2AServer", targets: ["A2AServer"]),
    ],
    targets: [
        .target(name: "A2A"),
        .target(name: "A2AClient", dependencies: ["A2A"]),
        .target(name: "A2AServer", dependencies: ["A2A"]),
        .testTarget(
            name: "A2ATests",
            dependencies: ["A2A"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "A2AClientTests", dependencies: ["A2AClient"]),
        .testTarget(name: "A2AServerTests", dependencies: ["A2AServer"]),
    ],
    swiftLanguageModes: [.v6]
)
