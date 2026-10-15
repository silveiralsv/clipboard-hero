// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardHero",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ClipboardHero"),
        .testTarget(name: "ClipboardHeroTests", dependencies: ["ClipboardHero"]),
    ]
)
