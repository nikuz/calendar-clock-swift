// swift-tools-version:5.9
import PackageDescription

#if os(macOS)
let rayLibPath = "libs/macos"
#else
let rayLibPath = "libs/linux-arm64"
#endif

let development = true

let package = Package(
    name: "CalendarClock",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.5.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.2"),
    ],
    targets: [
        // The C module that wraps raylib
        .target(
            name: "CRayLib",
            path: "CRayLib"
        ),
        // Your Swift executable
        .executableTarget(
            name: "CalendarClock",
            dependencies: [
                "CRayLib",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "CryptoExtras", package: "swift-crypto"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            path: "CalendarClock",
            linkerSettings: [
                .unsafeFlags(["-L\(rayLibPath)", "-lraylib"]),
                
                // macOS frameworks raylib needs:
                .linkedFramework("OpenGL",      .when(platforms: [.macOS])),
                .linkedFramework("Cocoa",       .when(platforms: [.macOS])),
                .linkedFramework("IOKit",       .when(platforms: [.macOS])),
                .linkedFramework("CoreVideo",   .when(platforms: [.macOS])),
                
                // Linux/Pi system libs:
                .linkedLibrary("drm",           .when(platforms: [.linux])),
                .linkedLibrary("gbm",           .when(platforms: [.linux])),
                .linkedLibrary("GLESv2",        .when(platforms: [.linux])),
                .linkedLibrary("EGL",           .when(platforms: [.linux])),
                .linkedLibrary("m",             .when(platforms: [.linux])),
                .linkedLibrary("pthread",       .when(platforms: [.linux])),
                .linkedLibrary("dl",            .when(platforms: [.linux])),
                .linkedLibrary("rt",            .when(platforms: [.linux])),
            ]
        ),
    ]
)
