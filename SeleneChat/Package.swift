// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SeleneChat",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SeleneChat",
            targets: ["SeleneChat"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "SeleneChat",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SeleneChatTests",
            dependencies: ["SeleneChat"],
            path: "Tests"
        )
    ]
)
