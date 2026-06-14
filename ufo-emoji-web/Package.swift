// swift-tools-version:6.2
import PackageDescription

// UFO Emoji — SpriteKit edition, on wasm.
//
// A WebAssembly port of Todd Bruss' iOS SpriteKit game "UFO Emoji" built on the
// SuperBox64 SpriteKit reimplementation. The ORIGINAL 14 Swift files compile
// UNCHANGED (symlinked into Sources/UFOEmoji by build.sh); every behavior gap is
// closed by extending SuperBox64Kit/WasmKit, never by editing the game.
//
// Depends on the LOCAL ../../SuperBox64Kit by path so kit changes are picked up
// directly during co-development.
let package = Package(
    name: "UFOEmojiWeb",
    dependencies: [
        .package(path: "../../SuperBox64Kit"),
    ],
    targets: [
        .executableTarget(
            name: "UFOEmoji",
            dependencies: [
                .product(name: "SpriteKit",      package: "SuperBox64Kit"),
                .product(name: "KitABI",         package: "SuperBox64Kit"),
                .product(name: "AppKit",         package: "SuperBox64Kit"),
                .product(name: "UIKit",          package: "SuperBox64Kit"),
                .product(name: "GameplayKit",    package: "SuperBox64Kit"),
                .product(name: "GameController", package: "SuperBox64Kit"),
                .product(name: "AVFoundation",   package: "SuperBox64Kit"),
            ],
            // Single-threaded wasm: nonisolated stack (matches the kit). Swift 5
            // language mode so the legacy game's global `var`s + deinits + nested
            // funcs compile UNCHANGED (Swift 6 global-concurrency checks off).
            swiftSettings: [.swiftLanguageMode(.v5)],
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
