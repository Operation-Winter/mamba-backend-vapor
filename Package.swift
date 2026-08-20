// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "mamba",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.122.0"),
        .package(url: "https://github.com/Operation-Winter/mamba-networking.git", from: "1.18.0"),
        .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.14.0")
    ], targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "MambaNetworking", package: "mamba-networking"),
                "OpenCombine",
                .product(name: "OpenCombineFoundation", package: "OpenCombine"),
                .product(name: "OpenCombineDispatch", package: "OpenCombine")
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [
            .target(name: "App")
        ]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "MambaNetworking", package: "mamba-networking"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ],
    swiftLanguageModes: [.v5]
)
