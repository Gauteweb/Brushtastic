// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Brushtastic",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Brushtastic",
            path: "Sources/Brushtastic",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
