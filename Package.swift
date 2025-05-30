// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Dragoboo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Dragoboo",
            targets: ["DragobooApp"]
        ),
        .library(
            name: "DragobooCore",
            targets: ["DragobooCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DragobooApp",
            dependencies: ["DragobooCore"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .target(
            name: "DragobooCore",
            dependencies: []
        ),
        .testTarget(
            name: "DragobooCoreTests",
            dependencies: ["DragobooCore"]
        ),
    ]
)