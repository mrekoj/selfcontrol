// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SelfControl",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SelfControlCore", targets: ["SelfControlCore"]),
        .executable(name: "SelfControlApp", targets: ["SelfControlApp"]),
        .executable(name: "selfcontrold", targets: ["SelfControlDaemon"]),
        .executable(name: "selfcontrol-cli", targets: ["SelfControlCLI"])
    ],
    dependencies: [
        // Add dependencies later (Sparkle 2, Sentry, etc.)
    ],
    targets: [
        .target(
            name: "SelfControlCore"
        ),
        .executableTarget(
            name: "SelfControlApp",
            dependencies: ["SelfControlCore"]
        ),
        .executableTarget(
            name: "SelfControlDaemon",
            dependencies: ["SelfControlCore"]
        ),
        .executableTarget(
            name: "SelfControlCLI",
            dependencies: ["SelfControlCore"]
        ),
        .testTarget(
            name: "SelfControlTests",
            dependencies: ["SelfControlCore"]
        )
    ]
)
