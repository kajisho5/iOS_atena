// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtenaCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AtenaCore", targets: ["AtenaCore"]),
    ],
    targets: [
        .target(name: "AtenaCore"),
        .testTarget(name: "AtenaCoreTests", dependencies: ["AtenaCore"]),
    ]
)
