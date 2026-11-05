// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TGBot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TGBot", targets: ["TGBot"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TGBot",
            path: "Sources"
        )
    ]
)
