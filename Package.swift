// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppSorter",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        .executableTarget(
            name: "AppSorter",
            path: "Sources/AppSorter"
        ),
    ]
)
