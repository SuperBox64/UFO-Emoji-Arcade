# 🚀 UFO Emoji Arcade

> **One 100% Swift SpriteKit codebase — Todd Bruss' App Store arcade game _UFO Emoji_ — shipped natively to iOS, to the browser via WebAssembly, and to native consoles, all from the same _unchanged_ game sources.**

![Swift](https://img.shields.io/badge/Swift-100%25-orange)
![SpriteKit](https://img.shields.io/badge/SpriteKit-native%20%2B%20reimplemented-blue)
![App Store](https://img.shields.io/badge/App%20Store-v1.1.0%20(build%2011)-black)
![WebAssembly](https://img.shields.io/badge/WebAssembly-wasip1%20%2F%20Embedded-654ff0)
![License](https://img.shields.io/badge/license-Proprietary-red)

🎮 **5-star App Store rating.** Available now in the iOS App Store for iPad and iPhone (iOS 14+).
🌐 **Now playable in the browser and on native consoles**, compiled from the same Swift source.

---

## What is this?

**UFO Emoji** is a side-scrolling emoji arcade shooter, originally an iOS SpriteKit app on the App Store (**v1.1.0, build 11**). This repository is the **flagship demo** of the [SuperBox64](https://github.com/SuperBox64) constellation: it takes the ~14 original Swift game files and compiles them **unchanged** for three radically different targets:

1. **Native Apple** — the original Xcode app (Metal + UIKit, real Apple SpriteKit).
2. **The browser** — Swift → WebAssembly, rendered on **Canvas2D**.
3. **Native consoles** — Embedded Swift + **SDL3** + **WAMR**/wasmtime cartridges.

The trick: **the original sources on disk are never edited.** Every platform gap is closed either by extending the [SuperBox64Kit](https://github.com/SuperBox64/SuperBox64Kit) SpriteKit reimplementation and the [WasmKit](https://github.com/SuperBox64/WasmKit) runtime, or by **build-time mechanical source transforms** (`sed`/`perl` inside `build.sh` and `build-embedded-game.sh`) that emit transformed _copies_ into the wasm target. The originals in `UFO Emoji/` remain the single source of truth, byte-for-byte buildable by Xcode.

> **Prime directive:** the ~14 original Swift game files **MUST compile UNCHANGED.** If a platform can't run the code, the _kit_ or the _runtime_ changes — not the game.

Every actor — the ship, enemies, power-ups, bosses, explosions — is drawn as **live emoji text** (`SKLabelNode` glyphs), not pre-rasterized sprites, on every platform. Exactly like the iOS original.

### The drop-in story

The game keeps every `import SpriteKit`, `import UIKit`, `import AVFoundation` line. On Apple platforms those resolve to the real frameworks. On wasm and native-console builds they resolve to **SuperBox64Kit** — a Swift reimplementation of SpriteKit (`SKScene`, `SKNode`, `SKLabelNode`, `SKPhysicsBody`, `SKAction`, `SKView`, the `UITouch`/`NSEvent`/`UIResponder` input chain, `GCController`, …) backed by **Box2D v3** for physics and a **reSVG/nanosvg** vector rasterizer for art. The same `GameScene.swift` runs on Metal, on Canvas2D, and on SDL3 without a single `#if os(...)` in the game logic.

---

## Where this repo sits in the constellation

This is **the game**. The other four repos are the engine and the consoles that play it.

```
                          ┌──────────────────────────────────────────────┐
                          │            UFO-Emoji-Arcade  (THIS REPO)      │
                          │   ~14 unchanged Swift game files (GameScene…) │
                          │   the single source compiled 3 ways           │
                          └───────────────────────┬──────────────────────┘
                                                   │ import SpriteKit / UIKit / AVFoundation
                  ┌────────────────────────────────┼────────────────────────────────┐
                  ▼                                 ▼                                 ▼
        ┌──────────────────┐            ┌────────────────────────┐         ┌────────────────────┐
        │  Apple SpriteKit │            │   SuperBox64Kit        │         │   SuperBox64Kit    │
        │  (real frameworks)│           │   SpriteKit-for-wasm   │         │   SDL3 native back │
        │  Metal + UIKit    │           │   + Box2D v3 + reSVG   │         │   end + Box2D+reSVG│
        └────────┬─────────┘            └───────────┬────────────┘         └─────────┬──────────┘
                 │                                  │  KitABI imports                 │
                 │                       ┌──────────┴───────────┐                     │
                 ▼                       ▼                      ▼                     ▼
        ┌────────────────┐     ┌──────────────────┐  ┌────────────────────┐ ┌───────────────────┐
        │  Xcode app     │     │  WasmKit          │  │  WasmCart          │ │  Wasm5            │
        │  iOS / iPadOS  │     │  runtime.js       │  │  WAMR + wamrc AOT  │ │  WKWebView carts  │
        │  macOS Catalyst│     │  Canvas2D browser │  │  SDL3 console      │ │  SDL3 console     │
        └────────────────┘     └──────────────────┘  └────────────────────┘ └───────────────────┘
```

| Repo | Role |
|---|---|
| **UFO-Emoji-Arcade** _(this)_ | **The flagship game/demo.** One SpriteKit codebase shipped to Apple, the web, and native consoles from a single source. |
| [SuperBox64Kit](https://github.com/SuperBox64/SuperBox64Kit) | **The kit.** Drop-in SpriteKit reimplementation for Embedded/wasm Swift + a native SDL3 backend. Owns SpriteKit emulation, KitABI, Box2D v3, SDL3, reSVG, `sks2json`. |
| [WasmKit](https://github.com/SuperBox64/WasmKit) | **The web runtime.** `runtime.js` — the hand-rolled, no-Emscripten Canvas2D host that fulfils the KitABI imports in the browser. |
| [WasmCart](https://github.com/SuperBox64/WasmCart) | **Native console.** Embedded-Swift + SDL3 shell that plays `.wasm`/`.aot` cartridges through WAMR (interpreter + `wamrc` AOT). |
| [Wasm5](https://github.com/SuperBox64/Wasm5) | **WebView console.** WasmCart's SDL3 shell, but carts play the _web_ build in a `WKWebView` (real Canvas2D/runtime.js stack), with SDL3 keystrokes forwarded as synthetic DOM events. |

---

## Features

A faithful, complete port of the App Store game — **not** a reduced demo.

- **Side-scrolling emoji arcade shooter:** 12 levels across **3 worlds** — 🌊 Water World (1–4), 🏜️ Sand Dunes (5–8), 🌌 Outer Space (9–12).
- **Three playable pilots/ships**, chosen on the title screen:
  - 👽 **Alien** flying a saucer
  - 🐵 **Monkey head** in a banana/rocket ship (cycling _Hear/See/Speak No Evil_)
  - 💩 **Poo emoji** in the PooShip
- **Live emoji actors:** every sprite is an `SKLabelNode` glyph rendered at runtime, never pre-rasterized.
- **GTFlightYoke** virtual flight stick with a diamond-circle 4-way fire/bomb button cluster; joystick side (left/right, fire on the opposite side) is configurable via `settings.stick`.
- **Box2D-backed SpriteKit physics** with **13 category bitmasks** (hero, world, badGuy, laserbeam, tractor, items, charms, …) and contact handling via `didBegin(_:)`. (On Apple the native SpriteKit physics path is used; on wasm/native the kit drives Box2D v3.)
- **Power-ups** dropped from wrecks:

  | Glyph | Effect |
  |---|---|
  | 🔫 | Double laser |
  | 💠 | Rapid fire |
  | 🛡 | Temporary shield |
  | 🔱 | Smart bomb (clears the screen) |
  | ❣️ | Extra life |
  | 💎 | Bonus points |

- **Boss fights** ("King/Queen") every 4th level with `KingQueenGlobalDie` health, plus friendly drifters (🐬 🦋 🦄 …) that float by for bonus points.
- **Scoring with high-score persistence** — `UserDefaults` natively, `localStorage` on the web — extra life every 5,000 points, **Ready·Set·Go** intro and Game Over / Level Up transitions.
- **Enemy pathfinder AI** (`GameBadGuyAI.DrawBadGuxAI`) with routed multi-node movement tables.
- **Original GarageBand soundtrack + custom SFX** (`music1`, `fire`, `doublelaser`, `murrmurr`, `Explosion1`, `boomFire`, `extralife`) and the `Emulogic.ttf` bitmap font.
- **Device-adaptive sizing:** iPad modes plus iPhone **626×352** (mode 2) and iPhone X **762×352** (mode 4); aspect ratios 1.3 / 1.4 / 1.5 / 1.8 / 2.2.
- **Lossless vector art pipeline:** ~700 `xcassets` PDFs converted to **SVG** at build time, rasterized crisply at the sprite's live device footprint by the runtime/kit.
- **Input on every target:** on-screen yoke + buttons, hardware keyboard, and the Web Gamepad API.

---

## Build × Runtime permutations

The same game source runs through **multiple real build × runtime permutations.** This repo participates directly in the wasm and native ones; the SDL3-native and console rows are owned by the sibling repos but play _this_ game's cartridge.

| # | Build (wasm flavor) | Host / runtime | Renderer | Output | Notes |
|---|---|---|---|---|---|
| 1 | **None — Apple-native** | Apple SpriteKit (`@UIApplicationMain` UIKit/AppKit app) | Metal + UIKit (`SKView`) | Xcode `.app` | The source of truth. `UFO Emoji/UFO Emoji/*.swift`, built by Xcode. iOS / iPadOS / macOS (Catalyst). Native SpriteKit physics. |
| 2 | **Full-Swift `wasm32-unknown-wasip1`** (SwiftPM, non-Embedded) | `runtime.js` in a browser (WASI shim) | **Canvas2D** (`<canvas>` 626×352) | `web/ufoemoji.wasm` **≈4.18 MB** | The primary shippable web build. Links the kit + Box2D v3 C. `release` ⇒ `-Osize` + `wasm-opt -Oz`. `index.html`. |
| 3 | **Embedded-Swift `wasm32`** (`-enable-experimental-feature Embedded`) | `runtime.js` (minified `runtime-embedded-min.js`) | **Canvas2D** (`embedded.html` 626×352) | `web/ufoemoji-embedded.wasm` **≈688 KB** (~257 KB gzip) | **~6× smaller** — the whole point of this permutation. Embedded stdlib + WASI libc + Box2D v3 + KitABI shim. |
| 4 | **None — Embedded-Swift native** (`arm64-apple-macos`) | SDL3 native backend (no wasm) | **SDL3 + Metal** | Single-file binary | "Straight to native." Owned by SuperBox64Kit `native/build-native-game.sh`. WAVs baked in, no runtime deps. |
| 5 | Full-Swift **or** Embedded cart `.wasm` | **WAMR interpreter** ([WasmCart](https://github.com/SuperBox64/WasmCart)) | SDL3 + Metal | cart `.zip` | Universal fallback — `\0asm` magic, runs interpreted. ~2.3 ms real work/frame, rest is vsync idle. |
| 6 | Full-Swift **or** Embedded cart, **`wamrc` AOT** → `.aot` | WAMR + AOT ([WasmCart](https://github.com/SuperBox64/WasmCart)) | SDL3 + Metal | cart `.zip` (`.aot` beside `.wasm`) | `\0aot` magic, native 60 fps. ELF arm64/x64 covers macOS+Linux+Android per arch; Windows-x64 COFF. |
| 7 | The web build, **unchanged** | **`WKWebView`** ([Wasm5](https://github.com/SuperBox64/Wasm5)) | Canvas2D inside WKWebView | served cart | Real browser stack inside the native console. SDL3 keystrokes forwarded as synthetic DOM `KeyboardEvent`s. |

**Two web payloads from one source:** the full Swift-stdlib `ufoemoji.wasm` (~4.18 MB) and the Embedded-Swift `ufoemoji-embedded.wasm` (~688 KB). Both are served by the **same** `runtime.js` from WasmKit — the embedded one just uses a terser-minified copy. The runtime is **never hand-forked**; `runtime.js` and `runtime-embedded-min.js` are copied/minified from WasmKit on every build.

---

## Build & Run

### 1. Native iOS / iPadOS / macOS (Xcode)

Open the project and build the **`UFO Emoji`** scheme.

```sh
open "UFO Emoji/UFO Emoji.xcodeproj"
# build the "UFO Emoji" scheme — iOS 14.0+, Swift 5.0, bundle id com.bruss.todd.UF-Emoji
```

This is the source of truth (`MARKETING_VERSION=1.1.0`, `CURRENT_PROJECT_VERSION=11`).

### 2. Full web build (Canvas2D, ~4.18 MB)

From `ufo-emoji-web/`:

```sh
./build.sh release    # -> web/ufoemoji.wasm (+ runtime.js + manifest.json), -Osize + wasm-opt -Oz
./build.sh debug      # fast, unoptimized
./build.sh assets     # re-run the .sks/asset pipeline + publish only
```

`build.sh` symlinks the original game files, applies the `.preCommon` `sed` transforms (e.g. `for touch: AnyObject in` → `for touch in`), runs `sks2json`, converts `xcassets` PDFs → SVG (`mutool`/`pdf2svg`), transcodes audio (`ffmpeg` m4a/mp3 → wav), runs `swift build` to a `wasip1` reactor + `wasm-opt`, regenerates `manifest.json`, copies/minifies WasmKit's `runtime.js`, and cache-busts `index.html`.

**Toolchain:** swift.org **Swift 6.3.2 RELEASE** + the `swift-6.3.2-RELEASE_wasm` SDK. Optional: `wasm-opt` (binaryen), `mutool`/`pdf2svg`, `ffmpeg`, `terser`. Use the 6.3.2 toolchain directly — a swiftly dev-snapshot (e.g. 6.5) can't import the 6.3.2 wasm SDK's stdlib.

### 3. Embedded-Swift web build (Canvas2D, ~688 KB)

Run `./build.sh release` first to populate `Sources/` + the KitABI shim, then:

```sh
# EMB_NOGC=1 omits --gc-sections to avoid a linker-strip OOB during the embedded build
EMB_NOGC=1 EMB_BUILD_DIR=/tmp/ufoemb bash docs/embedded/build-embedded-game.sh
cp /tmp/ufoemb/ufoemoji-embedded.wasm ufo-emoji-web/web/ufoemoji-embedded.wasm
```

This compiles the SpriteKit/AppKit/UIKit/AVFoundation kit modules + the game with `-enable-experimental-feature Embedded -wmo -Osize`, strips `@MainActor`/`weak`/`CIFilter`/`DispatchQueue.main`, de-existentializes delegates, links Box2D v3 + the KitABI shim + the embedded stdlib + WASI libc, and emits the ~688 KB cartridge.

### 4. Run the web builds

`file://` **won't work** — the runtime fetches the wasm + assets over HTTP.

```sh
# Full (non-embedded) build:
cd ufo-emoji-web/web && python3 -m http.server 8000
#   -> http://localhost:8000/             (index.html)

# Or serve from the repo root and open the embedded build:
python3 -m http.server 8000 --directory ufo-emoji-web/web
#   -> http://localhost:8000/embedded.html   (embedded build, minified runtime)
```

### 5. Native console

```sh
# WasmCart (Embedded Swift + SDL3 + WAMR): load ufoemoji.wasm or ufoemoji-embedded.wasm as a cart.
# See https://github.com/SuperBox64/WasmCart  — CTRL+ESC ejects.
```

### Tests & capture

From `ufo-emoji-web/`:

```sh
node tools/smoketest.mjs           # headless: instantiate wasm with stubbed env/WASI,
                                   # drive _initialize -> boot -> frame(dt) x N with synthetic
                                   # key events; assert it renders text/sprites + plays sound, no trap
node tools/shoot.mjs <baseUrl>     # Playwright (system Chrome): screenshot title + gameplay
```

---

## KitABI (the host boundary)

On wasm and native-console builds, the game's SpriteKit calls bottom out in **KitABI** — a flat C ABI of ~120 functions that the host (WasmKit's `runtime.js` in the browser, SDL3 natively) implements. This repo _consumes_ KitABI through SuperBox64Kit; the implementations live in **WasmKit** (web) and **SuperBox64Kit** (native). A representative slice:

| Group | Functions (examples) |
|---|---|
| **Graphics** | `gfx_clear`, `gfx_save`/`gfx_restore`, `gfx_translate`/`gfx_scale`/`gfx_rotate`, `gfx_fill_rect`, `gfx_fill_circle`, `gfx_fill_poly`, `gfx_draw_image`, `gfx_set_blend`/`gfx_set_tint`/`gfx_set_alpha` |
| **Text** | `gfx_draw_text`, `txt_width`, `gfx_set_text_baseline` — how live emoji glyphs reach the screen |
| **Assets** | `img_by_name`, `img_width`/`img_height`, `font_by_name`, `asset_text`, `asset_exists` |
| **Audio** | `snd_by_name`, `snd_play`/`snd_stop`, `snd_set_volume`, `eng_*` (the AVAudioEngine-shaped mixer) |
| **Input** | `key_pressed`, `mouse_x`/`mouse_y`/`mouse_button`, `evt_poll`, `gp_connected`/`gp_button`/`gp_axis` |
| **Window/misc** | `win_width`/`win_height`, `win_set_title`, `store_get`/`store_set` (high-score persistence), `js_log` |

The native backend omits the shader/lighting/video/debug/`sb64_*` math helper groups that the web runtime provides. The boot/frame contract this game exports sits on top of that surface (see API below).

---

## API / usage

The wasm cartridge is a **reactor module** with a tiny exported contract; everything else is the unchanged game.

```swift
// ufo-emoji-web/Sources/UFOEmoji/main.swift  — reactor entry
@_cdecl("boot")  public func boot()                 // builds SKView + GameViewController, runs viewDidLoad()
@_cdecl("frame") public func frame(_ dtMs: Double)  // advance one animation frame (gView.tick)
// Reactor exports (Package.swift linker flags): boot, frame, _initialize, memory
```

Key game-side types (compiled identically on every target):

```swift
protocol GameProtocol { func runGameMenu(); func runGameLevel() }
class GameViewController: UIViewController, GameProtocol         // viewDidLoad -> gameMenu()

protocol FlightYokeProtocol { func FlightYokePilot(velocity:zRotation:) }
class GTFlightYoke: SKNode                                       // startup/shutdown/stickMoved/update — NO private CADisplayLink

class GameScene: SKScene, FlightYokeProtocol,
                 SKPhysicsContactDelegate, AVAudioPlayerDelegate // didMove/update/touchesBegan/didBegin/...

// GameGlobal free functions:
loadSettings(); saveSettings(); loadScores(); saveScores()
getDeviceSize(); setSceneSizeForGame(); setSceneSizeForMenu()   // + the `settings` appsettings tuple

GameBadGuyAI.DrawBadGuxAI(...)                                   // enemy spawn / pathfinder AI builder
```

In reactor mode, `main.swift`'s `boot()` calls `loadSettings()` to stand in for the excluded `AppDelegate`, then constructs an `SKView` + `GameViewController` and calls `viewDidLoad()`.

---

## Cross-platform notes

These are the hard-won constraints behind the "compile unchanged" promise. The originals are never touched; the wasm builds emit transformed _copies_.

- **The ~14 originals must compile unchanged.** `build.sh` and `build-embedded-game.sh` generate transformed copies into `ufo-emoji-web/Sources/UFOEmoji`. Never edit the originals to fix a wasm build.
- **Build-time transforms are mechanical.** Common: `for touch: AnyObject in` → `for touch in`. The Embedded build additionally strips `@MainActor`, rewrites `[weak X]` → strong `Optional`, widens `CIFilter` radius to `Double`, maps `DispatchQueue.main` → `DispatchQueue.shared`, and **de-existentializes** `gameDelegate`/`FlightYoke.delegate` to concrete types (witness tables get GC-stripped under `-wmo --gc-sections`, otherwise → `call_indirect` trap).
- **`AppDelegate.swift` is excluded from both wasm builds.** Its `@UIApplicationMain` conflicts with the `boot()` reactor entry; `main.swift` calls `loadSettings()` in its place. It's also the Apple-only home of the `SKKey` enum + `skKeyIsDown()` stub (on wasm those come from the kit), so the same unconditional `pollKeyboardInput()` compiles everywhere.
- **`GTFlightYoke` must NOT own a private `CADisplayLink`.** The owning scene's `update(_:)` drives `FlightYoke.update()`. A per-object timer keeps ticking a torn-down scene after `presentScene` (Embedded strong-strip retain cycle) → "Out of bounds `call_indirect`". `SKAction.run` closures and `DispatchQueue.main` also crash under Embedded `-wmo`.
- **`logicalWidth`/`logicalHeight` 626×352 must match** across `index.html`/`embedded.html` `WASMWEB` and `manifest.json`. WasmCart's host reads them from the manifest — otherwise it falls back to 1920×1080 and renders tiny.
- **Asset pipeline ships only _real_ atlases as SVG;** emoji-glyph atlases are skipped (rendered as live `SKLabelNode` text). But placeholder atlases (`GameGrass_placeholders`, …) **are** exported so angular tile-definition names resolve to real sizes → correct trapezoid polygon bodies (skipping them made `size()=0` and bodies collapsed).
- **reSVG quirk:** `resvg` vertically flips PDF-derived SVGs with y-flip-matrix clipPaths (e.g. the `fire45`/`hud45` diamonds), so the kit ships librsvg-rendered PNGs in the cart; `imageByName` prefers `.png`.

---

## Keyboard / input

Touch (the on-screen flight yoke + diamond fire buttons) is the native input; the web and console builds add keyboard and gamepad.

| Action | Keyboard | Touch / Mouse | Gamepad |
|---|---|---|---|
| Fly | Arrows / WASD | Drag (virtual flight yoke) | Left stick |
| Fire | Space (hold) | Hold a fire button | A / Right trigger |
| Start / Restart | Space | Tap | A |
| Switch pilot (title) | 1 · 2 · 3 | Tap the pilot line | — |

`pollKeyboardInput()` is a single unconditional path that compiles on every target. It maps **WASD vs arrows to move-vs-fire by joystick side** and edge-triggers fire. On the web it reads `KeyboardEvent.code`; in the Wasm5 WebView console, SDL3 keystrokes are forwarded into the page as synthetic DOM `KeyboardEvent`s (SDL keys break when WebKit is linked).

---

## Repository layout

```
UFO-Emoji-Arcade/
├── UFO Emoji/                          # native iOS Xcode app — the ~14 game files (source of truth)
│   └── UFO Emoji/
│       ├── GameScene/GameScene.swift   # 2152-line gameplay scene
│       ├── GameGlobal/GameGlobal.swift # global state, device sizing, save/load
│       ├── GameViewController/         # GameViewController + AppDelegate (Apple-only)
│       ├── GTFlightYoke/               # virtual flight stick
│       ├── GameModel/GameBadGuyAI.swift
│       ├── GameLevels/                 # level1-12.sks
│       └── Assets.xcassets, GameFonts, GameMusic, GameSounds, GameParticles
├── ufo-emoji-web/                      # SwiftPM wasm target
│   ├── Package.swift                   # depends on ../../SuperBox64Kit (local path)
│   ├── build.sh                        # the web/wasm build driver
│   ├── Sources/UFOEmoji/               # main.swift + build-time-transformed game copies
│   ├── tools/{smoketest,shoot}.mjs
│   └── web/                            # published payload
│       ├── index.html, embedded.html
│       ├── ufoemoji.wasm, ufoemoji-embedded.wasm
│       ├── runtime.js, runtime-embedded-min.js   # from WasmKit (never hand-forked)
│       ├── manifest.json               # 626x352, fonts, ~700 SVGs, 9 sfx, scenes/particles
│       └── assets/{fonts,images,particles,scenes,sfx}
├── docs/embedded/build-embedded-game.sh
└── ufo-emoji-wasm-PLAN.md              # the migration plan (prime directive, kit-change list)
```

---

## Related repos

- **[SuperBox64Kit](https://github.com/SuperBox64/SuperBox64Kit)** — the SpriteKit-for-Embedded-Swift reimplementation this game keeps every `import SpriteKit` against. Consumed by local path `../../SuperBox64Kit`. Hosts `sks2json`, the KitABI shim, CBox2D, the SDL3 backend, and the reSVG texture runtime.
- **[WasmKit](https://github.com/SuperBox64/WasmKit)** — the single source of truth for `runtime.js` (Canvas2D renderer + Web Audio mixer + DOM/Web Gamepad input). `web/runtime.js` and `runtime-embedded-min.js` are copied/minified from it on every build.
- **[WasmCart](https://github.com/SuperBox64/WasmCart)** — the native console (Embedded Swift + SDL3 + WAMR/wamrc AOT) that plays the same `ufoemoji-embedded.wasm` cartridge; its host reads `logicalWidth`/`Height` from `manifest.json`.
- **[Wasm5](https://github.com/SuperBox64/Wasm5)** — the WebView console: WasmCart's SDL3 shell, but carts play in a `WKWebView` over the real Canvas2D/runtime.js stack with keyboard forwarding.
- **[AsteroidZ](https://github.com/SuperBox64/AsteroidZ)** — prior-art web port using the same single code-driven `GameScene` approach.

Origin: `https://github.com/SuperBox64/UFO-Emoji-Arcade.git`

---

## A message from Todd Bruss

> "I hope you enjoy **UFO Emoji** as much as I've enjoyed making it. This game embodies everything I love about creativity, independence, and the Apple ecosystem. It's not just about gaming — it's about pushing boundaries and showcasing what's possible when we create with passion. From a wireframe shown to Apple's Design Lead at **WWDC 2015** to a 2018 App Store debut and continuous updates through iOS 18, and now the **same source running in the browser and on native consoles** — here's to the future of independent game development."
>
> — **Todd Bruss**, Charlotte, North Carolina

**Development timeline:** 2015 wireframe (WWDC) · 2016 menu / pilot select · 2017 HUD & level design · **2018 App Store debut** · 2020 major update + iOS 14 (new levels, more power-ups, improved pathfinder AI) · 2023 iOS 17 · 2024 iOS 18, multi-aspect support, code cleanup.

---

## Credits & License

**Copyright © 2015–2024 Todd Bruss. All Rights Reserved.**

- **100% Swift**, built on SpriteKit. No AI-generated code, no templates — hand-drawn art (Photoshop / Illustrator vector PDFs), original GarageBand soundtrack and custom SFX. Built with pride in Charlotte, North Carolina.
- **Apple Color Emoji** is owned by **Apple, Inc.** and may be used only on Apple devices within the Apple ecosystem; the web build falls back to the host's emoji font.

### License — Proprietary (All Rights Reserved)

This repository is governed by the **UFO Emoji Source Code License Agreement** (see [`LICENSE`](LICENSE)). The source code is provided **for reference and personal review only**:

- You may **not** copy, distribute, modify, reproduce, publish, sublicense, or use the source code for any purpose (commercial, non-commercial, or educational).
- **No redistribution or derivative works.** No reverse engineering or extraction for use in other projects.
- This license grants **no permission** to integrate the source code into any software, product, or project.
- **Only Todd Bruss may submit this code to the App Store.** Access may be revoked at any time; unauthorized use will result in legal action.
- Provided **"as-is"** without warranties of any kind.
