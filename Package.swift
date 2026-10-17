// swift-tools-version:6.0
import PackageDescription

let swift5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "PoxiDrop",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PoxiDropCore", swiftSettings: swift5),
        .executableTarget(name: "PoxiDrop", dependencies: ["PoxiDropCore"], swiftSettings: swift5),
        .testTarget(name: "PoxiDropCoreTests", dependencies: ["PoxiDropCore"], swiftSettings: swift5),
    ]
)
