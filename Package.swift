// swift-tools-version:5.2
import PackageDescription

#if os(macOS)
    let CMeCab = "CMeCabOSX"
#else
    let CMeCab = "CMeCab"
#endif

let package = Package(
    name: "kotu.kez.io",
    platforms: [
       .macOS(.v10_15)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
        .package(name: "Gzip", url: "https://github.com/1024jp/GzipSwift.git", .branch("develop")),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0")),
        .package(url: "https://github.com/nodes-vapor/gatekeeper.git", from: "4.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "4.0.4")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Redis", package: "redis"),
                .product(name: "Gzip", package: "Gzip"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .target(name: "MeCab"),
                .product(name: "Gatekeeper", package: "gatekeeper"),
                .product(name: "Yams", package: "Yams")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(
            name: "MeCab",
            dependencies: [
                .target(name: CMeCab)
            ],
            cSettings: [
                .unsafeFlags(["-I/usr/local/include/"])
            ],
            swiftSettings: [
                .unsafeFlags(["-I/usr/local/include/"])
            ],
            linkerSettings: [.unsafeFlags(["-L/opt/homebrew/lib", "-L/usr/local/lib"])]
        ),
        .systemLibrary(name: CMeCab),
        .target(
            name: "Run",
            dependencies: [
                .target(name: "App")
            ]
        ),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor")
        ])
    ]
)
