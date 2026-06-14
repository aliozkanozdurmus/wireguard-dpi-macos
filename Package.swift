// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "wireguard-dpi-macos",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "wireguard-dpi-macos",
            targets: ["WireGuardDPIMacOS"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WireGuardDPIMacOS",
            dependencies: [],
            path: "Sources/WireGuardDPIMacOS",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
