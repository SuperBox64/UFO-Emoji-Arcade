// swift-tools-version:6.2
import PackageDescription

// UFO Emoji, SpriteKit edition, on wasm.
//
// A WebAssembly port of Todd Bruss' iOS SpriteKit game "UFO Emoji"
// (../UFO Emoji) built on the SuperBox64 SpriteKit reimplementation. The
// original ships as a UIKit app driven by binary .sks scene files and
// SKTileMapNode tilemaps — neither of which the wasm SpriteKit subset loads —
// so the gameplay is re-expressed here as a single code-driven GameScene that
// keeps `import SpriteKit` unchanged and renders every actor as live emoji
// text (the runtime draws SKLabelNode glyphs natively on Canvas2D).
//
// The package vends modules with Apple's exact framework names, so the game
// source needs no platform #if. Build with build.sh (swift.org toolchain +
// wasm SDK), serve the resulting web/ folder with WasmKit's runtime.js.
let package = Package(
    name: "UFOEmojiWeb",
    dependencies: [
        .package(url: "https://github.com/SuperBox64/SuperBox64Kit", branch: "embedded"),
    ],
    targets: [
        .executableTarget(
            name: "UFOEmoji",
            dependencies: [
                .product(name: "SpriteKit",      package: "SuperBox64Kit"),
                .product(name: "KitABI",         package: "SuperBox64Kit"),
                .product(name: "AppKit",         package: "SuperBox64Kit"),
                .product(name: "GameplayKit",    package: "SuperBox64Kit"),
                .product(name: "GameController", package: "SuperBox64Kit"),
                .product(name: "AVFoundation",   package: "SuperBox64Kit"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)],
            linkerSettings: [
                .unsafeFlags([
                    "-Xclang-linker", "-mexec-model=reactor",
                    "-Xlinker", "--export=boot",
                    "-Xlinker", "--export=frame",
                    "-Xlinker", "--export-if-defined=_initialize",
                    "-Xlinker", "--allow-undefined",
                ]),
            ]
        ),
    ]
)
