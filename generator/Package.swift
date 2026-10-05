// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "civitas-gen",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .target(name: "CivitasGenKit", dependencies: ["Yams"]),
        .executableTarget(name: "civitas-gen", dependencies: ["CivitasGenKit"]),
        .testTarget(name: "CivitasGenKitTests", dependencies: ["CivitasGenKit"]),
    ]
)
