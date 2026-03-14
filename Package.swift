// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vimursor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Vimursor",
            path: "Sources/Vimursor"
        ),
        .testTarget(
            name: "VimursorTests",
            dependencies: ["Vimursor"],
            path: "Tests/VimursorTests"
        )
    ]
)
