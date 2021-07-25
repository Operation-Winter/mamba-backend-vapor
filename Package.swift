// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "mamba",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(name: "mamba-networking", url: "https://github.com/Operation-Winter/mamba-networking.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "MambaNetworking", package: "mamba-networking")
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(name: "Run", dependencies: [
            .target(name: "App")
        ]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
