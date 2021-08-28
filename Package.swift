// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "mamba",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(name: "mamba-networking", url: "https://github.com/Operation-Winter/mamba-networking.git", from: "1.6.0"),
        .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.12.0")
    ],
    targets: [
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
        .target(name: "Run", dependencies: [
            .target(name: "App")
        ]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
