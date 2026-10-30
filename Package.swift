// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DailyNote",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DailyNote", path: "Sources/DailyNote")
    ]
)
