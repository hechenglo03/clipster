// swift-tools-version: 5.5
import PackageDescription

let package = Package(
    name: "Clipster",
    targets: [
        .executableTarget(
            name: "Clipster",
            path: "Sources/Clipster",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CryptoKit"),
                .linkedLibrary("sqlite3"),
            ]
        )
    ]
)
