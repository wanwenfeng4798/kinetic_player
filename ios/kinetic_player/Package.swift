// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "kinetic_player",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(name: "kinetic-player", targets: ["kinetic_player"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .binaryTarget(
            name: "SGPlayer",
            path: "../Frameworks/SGPlayer.xcframework"
        ),
        .target(
            name: "SgNativePlayerBridge",
            dependencies: ["SGPlayer"],
            path: "Sources/SgNativePlayerBridge",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedLibrary("iconv"),
                .linkedLibrary("bz2"),
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "kinetic_player",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "SgNativePlayerBridge",
            ],
            path: "Sources/kinetic_player"
        ),
    ]
)
