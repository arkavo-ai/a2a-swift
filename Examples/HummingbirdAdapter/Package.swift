// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "a2a-hummingbird-example",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "EchoTaskAgent",
            dependencies: [
                .product(name: "A2A", package: "a2a-swift"),
                .product(name: "A2AServer", package: "a2a-swift"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
