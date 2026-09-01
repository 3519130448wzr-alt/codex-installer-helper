// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexInstallerHelper",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodexInstallerCore", targets: ["CodexInstallerCore"]),
        .executable(name: "CodexInstallerHelper", targets: ["CodexInstallerApp"]),
        .executable(name: "CodexInstallerCoreTests", targets: ["CodexInstallerCoreTests"]),
    ],
    targets: [
        .target(name: "CodexInstallerCore"),
        .executableTarget(
            name: "CodexInstallerApp",
            dependencies: ["CodexInstallerCore"]
        ),
        .executableTarget(
            name: "CodexInstallerCoreTests",
            dependencies: ["CodexInstallerCore"],
            path: "Tests/CodexInstallerCoreTests"
        ),
    ]
)
