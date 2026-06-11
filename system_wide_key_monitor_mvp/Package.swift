// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "system_wide_key_monitor_mvp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "system_wide_key_monitor_mvp", targets: ["system_wide_key_monitor_mvp"]),
    ],
    targets: [
        .executableTarget(
            name: "system_wide_key_monitor_mvp",
            path: ".",
            exclude: [
                "README.md",
                "README_MVP_STATUS.md",
                "artifacts"
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
    ]
)

