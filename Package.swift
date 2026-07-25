// swift-tools-version: 6.3
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
        .package(url: "https://github.com/swhitty/FlyingFox.git", .upToNextMajor(from: "0.27.1"))
    ],
    targets: [
        .systemLibrary(
            name: "COpenSSL",
            pkgConfig: "libcrypto",
            providers: [
                .apt(["libssl-dev"])
            ]
        ),
        // The C module that wraps raylib
        .target(
            name: "CRayLib",
        ),
        // Your Swift executable
        .executableTarget(
            name: "CalendarClock",
            dependencies: [
                "COpenSSL",
                "CRayLib",
                .product(name: "FlyingFox", package: "FlyingFox"),
            ],
            resources: [
                .copy("Resources/fonts"),
                .copy("Resources/sounds"),
                .copy("Resources/shaders"),
                .copy("Resources/textures"),
            ],
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
        .testTarget(
            name: "CalendarClockTests",
            dependencies: ["CalendarClock"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
