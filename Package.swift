// swift-tools-version:5.9
import PackageDescription

#if os(macOS)
let libPath = "libs/macos"
#else
let libPath = "libs/linux-arm64"
#endif

let package = Package(
    name: "CalendarClock",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        // The C module that wraps raylib
        .systemLibrary(
            name: "CRayLib",
            path: "CRayLib",
            pkgConfig: nil,
            providers: nil
        ),
        // Your Swift executable
        .executableTarget(
            name: "CalendarClock",
            dependencies: ["CRayLib"],
            path: "CalendarClock",
            linkerSettings: [
                .unsafeFlags(["-L\(libPath)", "-lraylib"]),
                // macOS frameworks raylib needs:
                .linkedFramework("OpenGL",   .when(platforms: [.macOS])),
                .linkedFramework("Cocoa",    .when(platforms: [.macOS])),
                .linkedFramework("IOKit",    .when(platforms: [.macOS])),
                .linkedFramework("CoreVideo",.when(platforms: [.macOS])),
                // Linux/Pi system libs:
                .linkedLibrary("GL",    .when(platforms: [.linux])),
                .linkedLibrary("m",     .when(platforms: [.linux])),
                .linkedLibrary("pthread",.when(platforms: [.linux])),
                .linkedLibrary("dl",    .when(platforms: [.linux])),
                .linkedLibrary("rt",    .when(platforms: [.linux])),
            ]
        ),
    ]
)
