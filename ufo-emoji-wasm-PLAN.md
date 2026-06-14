# UFO Emoji → WebAssembly (SuperBox64Kit + WasmKit) — Migration Plan (v2, critique-incorporated)

> **Prime directive:** the **14 original Swift files** in `/Users/toddbruss/Documents/GitHub/UFOEmoji2020/UFO Emoji/UFO Emoji` compile and run **UNCHANGED**. Every behavior gap is closed by **extending SuperBox64Kit / WasmKit**, or — only where a per-game bridge is unavoidable (`@objc`/`#selector`/`@UIApplicationMain`/`weak` capture lists, all language-level and game-specific) — a thin `*Compat.swift` shim **plus a `.preCommon` mechanical rewrite** modeled on BossMan. The existing `ufo-emoji-web/Sources/UFOEmoji/GameScene.swift` (1325-line rewrite) and its generated `runtime.js`/`.wasm` are **discarded**; only `Package.swift`/`Package.resolved`, `build.sh`, the test harness (`smoketest.mjs`/`shoot.mjs`), `index.html`, and the pre-converted audio are salvaged.

This plan is grounded in the **actual code**, re-verified file-by-file. The first version of this plan contained false/misleading kit claims and omitted ~15 hard compile errors in the unchanged sources; this v2 corrects all of them and assigns every uncovered API a concrete disposition (already-supported **or** a named kit change).

---

## A0. Vector (SVG) texture pipeline — DECIDED; runtime ✅ DONE

The asset catalog is **702 vector PDFs + 1 raster (`bokeh.png`) + 13 AppIcon PNGs**; gameplay sprites are emoji `SKLabelNode`s. To preserve vectors **without quality loss**, the pipeline is **PDF → SVG at build time** (not PDF→PNG raster), and the runtime gained native lossless SVG support.

- **Why not PDF at runtime:** no browser image API decodes PDF (`createImageBitmap`/`<img>`/`drawImage` accept PNG/JPG/WebP/SVG, never PDF); shipping a PDF engine (PDFium/MuPDF wasm, multi-MB) is overkill. SVG natively carries vector `<path>`, embedded raster as base64 `<image>`, and `<clipPath>`/`<mask>` — nothing is lost.
- **Build step (asset stage of `build.sh`):** convert each `.imageset` PDF → SVG with `mutool convert` or `pdf2svg` (preserves embedded images + clip masks; **avoid Inkscape** — known mask/embedded-image export bugs). Verify with `grep -l "<image" assets/images/*.svg`. Emit `.svg` paths under `images` in `manifest.json`. `bokeh.png` stays raster.
- **Runtime (✅ implemented in `../WasmKit/runtime.js`, synced to `runtime-embedded.js`, min regenerated):**
  - `loadSVG()` keeps each SVG as a live `<img>` decoded via `img.decode()` (Safari-safe; `createImageBitmap(svgBlob)` is **not** supported in Safari). Intrinsic `width`/`height` synthesized from `viewBox` so `SKTexture.size` matches the source art 1:1.
  - `drawSVG()` rasterizes at the **exact device-pixel footprint** of the destination rect via `ctx.getTransform()` (baseScale already folds in DPR + camera zoom) → 1:1 draw, crisp at any zoom/HiDPI.
  - `svgRaster()` per-record LRU cache (≤8 sizes) → steady-state cost is one cached `drawImage`.
  - Embedded images + clip masks rendered by the browser's own SVG engine (we never flatten). No `abi.h` change; `gfx_draw_image` PNG path byte-identical.
- **Native/cartridge follow-up (not yet done):** the SDL backend has no browser SVG engine; add **resvg** (full fidelity incl. embedded images + masks) — nanosvg lacks `<image>` support. Tracked as a SuperBox64Kit native change.

> This **supersedes** any "rasterize PDF → PNG" step elsewhere in this plan, and adds one entry to §C Kit Changes: *WasmKit/runtime.js — lossless SVG textures (DONE)*.

### Locked decisions (Open Questions resolved)

1. **Device mode → iPhone, mode 2 (626×352).** `WASMWEB.logicalWidth=626, logicalHeight=352`; `UIDevice.userInterfaceIdiom = .phone` (Kit Change #15). `index.html` canvas `aspect-ratio: 626/352`.
2. **Audio → transcode to `.wav` (SFX) + `.ogg` (music).** Universal browser support; reuse the already-converted assets in `ufo-emoji-web/web/assets/sfx/`. Kit Changes #16/#17 (AVAudioPlayer loop + playSoundFileNamed wait) still apply.
3. **Emoji → host-font near-parity.** Use the browser's emoji font (Kit Change #20 maps `Apple Color Emoji` → host emoji font); accept minor glyph-metric/hitbox drift vs iOS. No bundled emoji font, no licensing exposure.

---

## A. Target architecture & `ufo-emoji-web` repo layout

Mirrors `BossMan/boss-man-spritekit-web`: one SwiftPM executable, the 14 game files symlinked in unchanged, thin platform wrappers + compat shims, and a `build.sh` that compiles to reactor-mode wasm, runs sks2json, rasterizes assets, and copies WasmKit's `runtime.js`.

**Decisive correction to the boot model.** The original `GameViewController.gameMenu()`/`gameLevel()` both begin with `guard let view = self.view as? SKView` (verified `GameViewController.swift:45` and `:82`). In the kit, `UIViewController.view` is typed `UIView` (verified `UIKit.swift:110`) and `SKView` is **not** a `UIView` subclass (`public final class SKView`, `SKView.swift:28`). That downcast can **never** succeed, so both methods return early and **no scene is ever presented**. There is also **no `skView` property** on `GameViewController` (only the two `as? SKView` sites). Therefore:

- We **do not** route boot through `GameViewController` (the BossMan way is to present the scene directly onto a globally-held `SKView`), **and**
- We **also fix the kit** so `self.view as? SKView` succeeds for any game that does instantiate a `GameViewController` (Kit Change #1). Both are needed: the kit fix makes the unchanged `GameViewController` path work *if reached*, and the direct-present `main.swift` guarantees a tick-able `SKView` exists regardless. `main.swift` constructs a `GameViewController`, assigns its `.view` to a real `SKView` (now type-legal after Kit Change #1), calls `viewDidLoad()` → `gameMenu()`, and holds that `SKView` for `frame()`.

```
UFOEmoji2020/
├── UFO Emoji/UFO Emoji/            # ORIGINAL game (read-only source of truth; never edited)
│   ├── GameScene/{GameScene.swift, Extensions.swift}
│   ├── GameModel/{GameTimeMapRun.swift, GameWorld.swift, GameBadGuyAI.swift, GameParallax.swift}
│   ├── GameMenu/GameMenu.swift
│   ├── GTFlightYoke/GTFlightYoke.swift
│   ├── GameGlobal/GameGlobal.swift
│   ├── GameTransitions/{StartUp.swift, LevelUp.swift, GameOver.swift}
│   ├── GameViewController/{GameViewController.swift, AppDelegate.swift}
│   ├── GameLevels/level1..12.sks, GameScene/GameScene.sks, GameMenu/GameMenu.sks
│   ├── GameParticles/*.sks, GameTileSets/new_/*.sks
│   ├── Assets.xcassets/** (35 atlases, 702 PDFs + bokeh.png), GameFonts/emulogic.ttf
│   └── GameMusic/*, GameSounds/*
│
└── ufo-emoji-web/                  # WASM target (restored from git HEAD: 33ffdcf, then re-pointed)
    ├── Package.swift               # EDIT: ADD the UIKit product (original imports UIKit; salvaged manifest omits it)
    ├── Package.resolved            # SALVAGE (pins SuperBox64Kit embedded branch e460d977…)
    ├── build.sh                    # EXTEND: symlink loop + .preCommon transform + sks2json loop + atlas/font/audio steps
    ├── Sources/UFOEmoji/
    │   ├── main.swift              # REWRITE: GameViewController + SKView(global) → viewDidLoad() → gameMenu()
    │   ├── (14 symlinks)           # 12 plain symlinks + 2 GENERATED copies (AppDelegate, GTFlightYoke, GameViewController) via .preCommon
    │   ├── UFOInputCompat.swift    # per-game shim: per-node touch dispatch + CADisplayLink→per-frame hook (see §B.3)
    │   ├── UFOAppLifecycleCompat.swift # per-game shim: @UIApplicationMain bridge + applicationState seed
    │   └── (DELETE old GameScene.swift rewrite, old runtime.js, old ufoemoji.wasm)
    ├── tools/{smoketest.mjs, shoot.mjs}   # SALVAGE unchanged
    └── web/
        ├── index.html              # SALVAGE; set WASMWEB.logicalWidth/Height = boot scene size (mode-driven; see Open Q)
        ├── manifest.json           # regenerated by build.sh
        ├── runtime.js              # copied from WasmKit by build.sh
        ├── ufoemoji.wasm           # build artifact
        └── assets/{fonts,images,scenes,particles,sfx}/
```

> **Working-tree note:** the salvageable files are tracked at git `HEAD` (`33ffdcf`) but are **not currently checked out** into the working tree. Phase 0 restores them with `git checkout HEAD -- ufo-emoji-web` (or `git restore --source=HEAD --staged --worktree ufo-emoji-web`) before editing.

**Runtime contract (unchanged from BossMan/WasmKit):** WASI reactor mode exports `_initialize`, `boot`, `frame(dtMs)`, `memory`. `runtime.js` preloads `manifest.json` (fonts/images/sounds/texts) via `FontFace`/`createImageBitmap`/`decodeAudioData`/`fetch().text()` before `boot()`. **No `include/abi.h` change is required** — the `gfx_*/snd_*/img_*/txt_*/asset_*/store_*` surface UFO needs (2D draw, emoji text with `gfx_set_text_baseline(1)`, `gfx_set_filter` for blur, looping/simultaneous audio, input, `store_*`) all exist. All WasmKit work is in `runtime.js` (asset-dir scan + font fallback).

---

## B. Source migration: 14 files unchanged + entry point + compat shims

### B.1 Symlinks + `.preCommon` mechanical rewrites (in `build.sh`)

`build.sh` (re)creates a symlink per original file so `swift build` sees one source tree of byte-for-byte iOS originals. **Three** files use language-level constructs Embedded Swift / the wasm entry cannot express; for those, the `.preCommon` pattern copies the original to a backup and materializes a **generated, non-symlinked** copy with a mechanical, behavior-preserving rewrite — the original on disk is **never touched**:

| File | Construct | `.preCommon` rewrite |
|---|---|---|
| `AppDelegate.swift` | `@UIApplicationMain` (synthesizes a UIKit `main`), `UIApplication.LaunchOptionsKey`, `UIWindow?` | Strip `@UIApplicationMain` (entry is `boot()`). The kit already provides `UIApplicationDelegate` (empty protocol), `UIResponder`, `UIWindow`. **`UIApplication.LaunchOptionsKey` does not exist in the kit → Kit Change #9 adds it** so the unchanged `didFinishLaunchingWithOptions(_:launchOptions:)` signature type-checks. `loadSettings()` is invoked from `main.swift`. |
| `GTFlightYoke.swift` | `CADisplayLink(target:selector:#selector(update))`, `@objc func update()`, `RunLoop.current/.common` | Replace the `@objc`/`#selector`/`CADisplayLink` registration with a call into `UFOInputCompat` that registers `update()` on the per-frame hook. (`@objc`/`#selector` are forbidden in Embedded.) |
| `GameViewController.swift` | `[weak view]` capture lists in **both** `DispatchQueue.main.async` closures (`:49`, `:88`); Embedded forbids `weak`/`unowned` unless `unsafe`; `@objc`-free but uses orientation/lifecycle overrides | Rewrite `[weak view]` → `[view]` (strong capture; the closure runs same-frame on the single-threaded wasm loop, so no retain cycle and no behavior change). The orientation/status-bar/memory overrides are handled by **Kit Change #2** (adds the override surface to `UIViewController`); `showsLargeContentViewer` by **Kit Change #3**. |

> Everything reusable goes into the kit (§C). `.preCommon` is reserved strictly for language-level constructs that *cannot* be expressed without editing the file (attributes, selectors, weak captures).

### B.2 `main.swift` (REWRITE)

Reproduces the original boot intent — `AppDelegate.didFinishLaunching → loadSettings()`, then `GameViewController` presenting `GameMenu(fileNamed:"GameMenu")` — while guaranteeing a tick-able `SKView`:

```swift
import SpriteKit
import UIKit
import KitABI

nonisolated(unsafe) var gvc: GameViewController? = nil
nonisolated(unsafe) var gView: SKView? = nil   // the tickable view, held for frame()

private func bootBody() {
    loadSettings()                         // GameGlobal: seeds settings.* from store
    UIApplication.shared.applicationState = .active   // Kit Change #8 default; demo branch GameScene.swift:967
    let c = GameViewController()
    let v = SKView()                       // SKView is now a UIView subclass (Kit Change #1)
    c.view = v                             // legal: c.view: UIView, v: SKView <: UIView
    gView = v
    c.viewDidLoad()                        // → gameMenu(): self.view as? SKView SUCCEEDS now,
                                           //   enqueues presentScene on DispatchQueue.main
    gvc = c
}

#if hasFeature(Embedded)
@_cdecl("boot")  public func boot() { bootBody() }
@_cdecl("frame") public func frame(_ dtMs: Double) { gView?.tick(dtMs) }
#else
@_cdecl("boot")  public func boot()  { MainActor.assumeIsolated { bootBody() } }
@_cdecl("frame") public func frame(_ dtMs: Double) { MainActor.assumeIsolated { gView?.tick(dtMs) } }
#endif
```

**Deferred-present sequencing (critique fix).** `gameMenu()`/`gameLevel()` wrap `presentScene` in `DispatchQueue.main.async`. The kit drains `DispatchQueue.pending` in `KitRunLoop._tick` during `SKView.tick` (verified `SKView.swift:127`). Ordering: `boot()` builds the view and enqueues the present; the **first** `frame()` calls `gView.tick()`, which drains the queue (running `presentScene`), then proceeds. The very first tick presents and renders the menu — correct, because a tick-able `SKView` provably exists (we hold it in `gView`, independent of the `as? SKView` path). Scene transitions (`runGameMenu`/`runGameLevel` and StartUp/LevelUp/GameOver via `gameDelegate`) all go through `presentScene`, which tears down the prior scene (`SKView.swift:54`).

### B.3 Per-game compat shims (modeled on BossMan `*Compat.swift`)

| Shim file | Bridges | How |
|---|---|---|
| `UFOInputCompat.swift` | (a) **per-node** touch dispatch; (b) CADisplayLink tick | **(a)** The kit delivers touches **only to the scene** via `SKScene.touchBegan(finger:at:)` (verified `SKView.swift:161-163`); there is **no hit-test/dispatch to child nodes** by `isUserInteractionEnabled`. The flight stick (`GTFlightYoke`, an `SKNode` with `isUserInteractionEnabled=true` and its own `touchesBegan/Moved/Ended`) and HUD fire buttons depend on per-node iOS delivery. **This requires Kit Change #10** (node-level touch routing in `SKScene`'s touch entry points). The shim then: overrides the scene's kit hooks, synthesizes a `Set<UITouch>` (one `UITouch` whose `location(in:)` returns the point), and forwards to the game's `touchesBegan/Moved/Ended` on the scene; Kit Change #10 additionally walks the node tree so the synthesized touch reaches the stick/buttons. **(b)** Registers `GTFlightYoke.update()` on the kit's per-frame hook (`KitRunLoop.addPerFrameHook`, verified `FoundationShims.swift`/`GameController.swift:63`) so the stick ticks once per frame in place of `CADisplayLink`. |
| `UFOAppLifecycleCompat.swift` | `@UIApplicationMain` entry, `applicationState` seed | Provides the stripped `AppDelegate` entry as a plain func and seeds `UIApplication.shared.applicationState = .active` (Kit Change #8 supplies the property). `AppDelegate` itself is never instantiated by `boot()`, but it must still type-check — Kit Change #9 supplies `UIApplication.LaunchOptionsKey`; `UIWindow?`/`UIApplicationDelegate`/`UIResponder` already exist (`UIKit.swift:31,47,133`). |

> Already in the kit (no shim, **verified**): `UIScreen.main.bounds`, `UIDevice.current.userInterfaceIdiom`, `UIColor=SKColor`, `UIImage=NSImage`, `UIFont=NSFont`, `UserDefaults`, `DispatchQueue`, `AVAudioPlayer`, physics joints/bodies/fields, `UITouch`/`UIEvent` stubs. **Not** already covered (each gets a kit change in §C): `UIBezierPath` curve/arc, `SKNode.copy()`, `childNode("//")`, `UIGraphics*`/`UIImageWriteToSavedPhotosAlbum`, `SKView`-as-`UIView`, the `UIViewController` override surface, `showsLargeContentViewer`, `applicationState`, `LaunchOptionsKey`, `CIFilter` type, `SKTileMapNode` API, the `SKSceneLoader` tile case, `playSoundFileNamed` wait sequencing, the AVAudioPlayer post-play loop set, the negative-falloff field math, and anchorPoint-aware rendering.

---

## C. Kit extensions (prioritized) — extend the framework, not the game

**P0 = hard compile failure or empty game; P1 = wrong gameplay; P2 = visual/polish.** Every row was re-verified against the kit source on disk.

| # | Pri | File(s) | Feature to add | Why the unchanged game needs it (verified) |
|---|----|------|----------------|---------------------------------|
| 1 | **P0** | `SpriteKit/SKView.swift` (+ `SKView.swift`/`UIKit.swift` for the `UIView` base) | **Make `SKView` a `UIView` subclass** so `self.view as? SKView` succeeds. Because `UIView` lives in the UIKit module and `UIView`↔`SKView` would invert the package dep graph (`UIKit` depends on `SpriteKit`, not vice-versa — verified `Package.swift`), relocate a **minimal `UIView`/`UIResponder` base into the SpriteKit module** (or KitABI) and re-export from UIKit via `public typealias UIView = …`. Drop `final` from `SKView`; have `SKView: UIView`. Add the SKView props the game sets but that are absent: `isMultipleTouchEnabled`, `isOpaque`, `clipsToBounds`, `backgroundColor` (color), and make `UIViewController.view` accept an `SKView`. | `GameViewController.swift:45,82` do `self.view as? SKView`; with `view: UIView` and `SKView` not a `UIView`, the cast is **structurally impossible** → no scene ever presents. Also `:107-113` set `isMultipleTouchEnabled/allowsTransparency/isAsynchronous/isOpaque/clipsToBounds/ignoresSiblingOrder` and `view.backgroundColor` — several absent from `SKView`. |
| 2 | **P0** | `UIKit/UIKit.swift` (`UIViewController`) | Declare overridable members: `open var shouldAutorotate: Bool`, `open var supportedInterfaceOrientations: UIInterfaceOrientationMask`, `open var preferredScreenEdgesDeferringSystemGestures: UIRectEdge`, `open var prefersHomeIndicatorAutoHidden: Bool`, `open var prefersStatusBarHidden: Bool`, `open func didReceiveMemoryWarning()`. Add the supporting types **`UIInterfaceOrientationMask`** (OptionSet: `.landscapeRight/.landscapeLeft/.all/…`) and **`UIRectEdge`** (OptionSet: `.bottom/.all/…`) — both absent from the kit (verified). | `GameViewController.swift:117-138` overrides **all six**; each is `error: does not override any declaration from its superclass` today. Compile blocker. Reusable → kit, not shim. |
| 3 | **P0** | `SpriteKit/SKView.swift` | Add `public var showsLargeContentViewer: Bool = false` (no-op). | `GameViewController.swift:110` sets it; absent from `SKView` (verified). Compile blocker. |
| 4 | **P0** | `AppKit/AppKit.swift` (`NSBezierPath`, re-exported as `UIBezierPath`) | Add `func addQuadCurve(to:controlPoint:)` (→ `cgPath.addQuadCurve`), `func addCurve(to:controlPoint1:controlPoint2:)` (defensive), and a failable/total `convenience init(arcCenter:radius:startAngle:endAngle:clockwise:)` (→ `cgPath.addArc(center:radius:startAngle:endAngle:clockwise:)`). | `NSBezierPath` today has only `move/line/close/init(rect:)/init(ovalIn:)` (verified `AppKit.swift:57-64`). The game uses `addQuadCurve(to:controlPoint:)` **8×** (`GameBadGuyAI.swift:132-138` — the entire enemy patrol-path system) and `UIBezierPath(arcCenter:radius:startAngle:endAngle:clockwise:)` (`GameTimeMapRun.swift:353` — the `🛑` field circle edge body). Two hard compile errors. **Verify `CGMutablePath.addArc/addQuadCurve` exist** (dossier lists `CGPath.addArc/addCurve`); if `addQuadCurve` is missing on `CGMutablePath`, add it too (degree-elevate the quad to a cubic, or sample). |
| 5 | **P0** | `SpriteKit/SKNode.swift` + `SKSpriteNode.swift` | Add `func copy() -> Self` deep-copy on `SKNode` (clone transform/name/zPosition/alpha/userData + recursively clone children) and override on `SKSpriteNode` (clone `texture/size/anchorPoint/color/colorBlendFactor/blendMode` **and** rebuild `physicsBody` if present). Must support `copy() as! SKSpriteNode`. | Absent today (verified). `GameParallax.swift:48` (`sprite.copy() as! SKSpriteNode`), `GameScene.swift:1991` (`👁.copy() as! SKSpriteNode`), `:2011` (`👁.copy()`), `:2068` (`💣.copy() as! SKSpriteNode`). Compile **and** runtime-crash path (force-cast). |
| 6 | **P0** | `SpriteKit/SKNode.swift` | Make `childNode(withName:)` honor the leading `//` **recursive descendant** syntax: if `name` starts with `//`, search the whole subtree for a node whose `name` equals the remainder (and support trailing path components if present). Keep flat behavior for plain names. | Today it is a flat `children.first { $0.name == name }` (verified `SKNode.swift:100`). `GameWorld.swift:43` calls `referenceNode.childNode(withName: "//" + name)` to find `SKTileMapNode` **descendants**; flat matching returns nil for every layer → **no tile map found → no level loads**. |
| 7 | **P0** | `Tools/sks2json/main.swift` + `SpriteKit/SKSceneLoader.swift` + `SpriteKit/SKStubs.swift` | **(a) sks2json:** extend `encode()` to handle `SKTileMapNode` — emit `kind:"SKTileMapNode"`, `tileSize`, `numberOfColumns`, `numberOfRows`, and a per-cell array `{column,row,definitionName,name,userData{…},flipHorizontally,flipVertically,textures:[…]}` read via `tileDefinition(atColumn:row:)`; also emit any node's `physicsBody` (rect/circle only). **(b) SKSceneLoader:** add `case "SKTileMapNode"` to `build(from:)` (currently the `default` at `:172` collapses it to a bare `SKNode`) that reconstructs the map and rehydrates each cell's `SKTileDefinition` incl. `userData` (`NSMutableDictionary`) + `name`; also make `applyCommonProps` apply `userData` (today it does not — verified `:187-196`). **(c) SKStubs:** see #8. | sks2json `encode()` covers only Scene/Sprite/Label/Shape/Emitter (verified `:113-160`) — **no tile data, no physics, no userData**. UFO's entire level geometry + AI waypoints live in `SKTileMapNode` cell `userData` (`isGrass/isDirt/isStone/isQtr/isCorner/isEnd/name/sector`) and 3-char emoji tile names (`📈` waypoints, `👾` spawns). Without this, levels are blank. |
| 8 | **P0** | `SpriteKit/SKStubs.swift` (`SKTileMapNode`/`SKTileSet`/`SKTileGroup`/`SKTileDefinition`) | Add the exact API the game calls: `func tileDefinition(atColumn:row:) -> SKTileDefinition?` (**missing** — only `tileGroup(atColumn:row:)` exists, `:623`); make `tileSize` **settable** (it is `let`, `:603`; game assigns `tileMap.tileSize` in `GameWorld.swift:61`); add `static func empty() -> SKTileGroup` (**missing**); add `func setTileGroup(_:andTileDefinition:forColumn:row:)` (**missing** — only `setTileGroup(_:forColumn:row:)` exists, `:619`). | `GameWorld.setupLevel` (`GameWorld.swift:83-96`) calls `tileDefinition(atColumn:row:)`, reassigns `tileSize`, and calls `SKTileGroup.empty()` + `setTileGroup(_:andTileDefinition:forColumn:row:)`. **Correction vs v1:** `tileSet` is **already `var`** (`:604`) and `SKTileSet.init()` already exists (`:597`) — those sub-items are **not** gaps. |
| 9 | **P1** | `UIKit/UIKit.swift` (`UIApplication`) | Add `public enum UIApplicationState { case active, inactive, background }` and `nonisolated(unsafe) public var applicationState: UIApplicationState = .active` on `UIApplication`. | `GameScene.swift:967` switches on `UIApplication.shared.applicationState` for the demo/rapidfire branch. Missing → compile failure. Reusable → kit. |
| 9b | **P0** | `UIKit/UIKit.swift` (`UIApplication`) | Add `public struct LaunchOptionsKey: Hashable` (typed key for the launch-options dict). | `AppDelegate.swift:16` signature `application(_:didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey: Any]?)` must type-check (the `.preCommon` AppDelegate still compiles even though it is never instantiated). Absent today. |
| 10 | **P0** | `SpriteKit/SKScene.swift` (touch entry points) | In the scene's `touchBegan/Moved/Ended(finger:at:)`, **hit-test the node tree** and deliver the synthesized touch to the deepest node with `isUserInteractionEnabled == true` (its own `touchesBegan/Moved/Ended`), falling back to the scene. Reuse `nodes(at:)` (`SKNode.swift:184`). | The kit routes touches **only to the scene** (`SKView.swift:161-163`); `GTFlightYoke` and the HUD fire buttons are interactive `SKNode`s relying on per-node iOS delivery. Without this the **flight stick and fire buttons are dead** — the game is unplayable. The `UFOInputCompat` shim cannot synthesize node-level dispatch by itself; the scene-side walk must exist in the kit. |
| 11 | **P1** | `SpriteKit/SKView.swift` + `SKScene.swift` | **Honor `scene.anchorPoint`** in both `render(_:)` and the touch→scene coordinate conversion (`scenePoint`, and `UITouch.location(in:)`). Apply `+ anchorPoint·size` (with the y-flip) so origin placement matches Apple when `anchorPoint != (0,0)`. | `SKView.render` ignores `anchorPoint` entirely (verified: no `anchorPoint` reference in `SKView.swift`). The game sets `scene.anchorPoint = (1,1)` for gameplay (`GameViewController.swift:80`) while bounds math is centered (`-w/2…w/2`); StartUp/LevelUp use `(0,0)`, GameOver `(0.5,0.5)`. Without anchor-aware render+touch, the whole HUD/bounds/touch layout is shifted by the scene size and the game is misaligned/unplayable. |
| 12 | **P0** | `SpriteKit/SKStubs.swift` (`CIFilter`) + `Extensions.swift` call site **(kit-only)** | Make `CIFilter(name:parameters:)` accept the game's literal. Today `init?(name:parameters: [String:Double]?)` (`:286`); `Extensions.swift:15` passes `["inputRadius": radius (CGFloat/Float), "inputAngle": CGFloat.pi/2]` — a **mixed-type dictionary** that will not coerce to `[String:Double]`. **Change the kit init to `init?(name:parameters: [String: CGFloat]? = nil)`** (or `[String: Any]?`), and recognize `name:"CIMotionBlur"` (`inputRadius`/`inputAngle`) → map to `gfx_set_filter("blur(Npx)")` in `SKEffectNode`. | **Severity correction vs v1:** this is a **P0 compile error** (type mismatch), not a P2 visual polish item. `Extensions.addGlow` (`Extensions.swift:15`) is unconditional code. Changing the kit's parameter type (CGFloat == Double on this target, but the literal contains `CGFloat.pi/2` which the compiler types as `CGFloat`) lets the unchanged dictionary literal type-check. |
| 13 | **P1** | `SpriteKit/SKExtras.swift` (`playSoundFileNamed`) | Honor `waitForCompletion`: when `true`, sequence so the action's duration equals the clip length (poll `snd_status`, or register on the audio-completion hook `SKView.swift:11`) instead of returning immediately. **Correction vs v1:** the function **already exists** (`SKExtras.swift:33`) — it is **not** a compile blocker. It currently hardcodes `snd_play(h, 100, 0)` and ignores `wait`. | `GameScene.swift` calls `playSoundFileNamed(_:waitForCompletion:)` ~15×; some pass `waitForCompletion: true` and chain on completion. Without wait sequencing, those sequences fire early (gameplay/audio timing off). Fidelity fix. |
| 14 | **P1** | `AVFoundation/AVFoundation.swift` (`AVAudioPlayer`) | Make `numberOfLoops` **live**: if set **after** `play()` while a voice is active, restart/retag the voice's loop flag (or stop+replay with the new loop state). Today loop is bound **only at play() time** via `numberOfLoops < 0 ? 1 : 0` (verified `:87`). | `GameScene.swift:953,1767` set `audioPlayer?.numberOfLoops = -1` **after** `play()`, and toggle to `0` elsewhere; with the current binding the already-started music voice never changes loop state → music either stops looping or never stops. Lifecycle parity. |
| 15 | **P1** | `SpriteKit/SKPhysics.swift` (field models) | Support **negative falloff** for `radialGravityField`/`springField`. Today `applyFields` only attenuates when `f.falloff > 0` (verified `:656`: `(f.falloff > 0 && dist > 0) ? 1/pow(dist,falloff) : 1`), so the `🛑` portal's `falloff = -0.05` is a **no-op** (`atten = 1`). Implement the full `pow(dist, falloff)` form for negative exponents (force *grows* with distance), and tune to Apple's sign/strength for UFO's `💢` springField (strength 1, minRadius 352) and `🛑` radialGravity (strength 0.1, falloff -0.05, minRadius 1400). | Fields are wired (`applyFields` `:643`, spring/radialGravity cases present), but the negative-falloff branch is literally ignored → black-hole/portal feel will **not** match Apple. This is a **real math change**, not "verify/tune". |
| 16 | **P0** | `SpriteKit/SKStubs.swift` (`SKReferenceNode`) | Add a **failable** `convenience init?(fileNamed:)` that routes through `SKSceneLoader.loadNode(fileNamed:)`, attaching the resolved tree as a child so `.children.first?.children` and `.resolve()` behave like Apple's (eager-load; keep `.resolve()` a no-op). **Correction vs v1:** the SKSceneLoader already resolves `SKReferenceNode` children when building from JSON (`SKSceneLoader.swift:163-169`); the **standalone** `SKStubs.SKReferenceNode.init(fileNamed:)` is **non-failable** (`init`, `:234`), but `GameWorld.swift:31` uses it in `guard var referenceNode = SKReferenceNode.init(fileNamed:…)`, which requires a **failable** init. | The precise compile issue is the failable-init mismatch (not "empty node"). `GameWorld.gameLevel` (`GameWorld.swift:31-43`) does `guard var referenceNode = SKReferenceNode(fileNamed: filename)`, then `childNode(withName:"//"+name)` (needs #6), then reads tile maps. |
| 17 | **P0** | `UIKit/UIKit.swift` (UIGraphics + Photos) | Add no-op/compile-only shims: `func UIGraphicsBeginImageContextWithOptions(_:_:_:)`, `func UIGraphicsGetImageFromCurrentImageContext() -> UIImage?` (return nil), `func UIGraphicsEndImageContext()`, `func UIImageWriteToSavedPhotosAlbum(_:_:_:_:)`, and `UIView.drawHierarchy(in:afterScreenUpdates:) -> Bool`. | `GameScene.swift:636-640` calls all five (the `demoMode` screenshot path). `demoMode` is `false` at runtime so it is dead, **but it is unconditional code** and must compile. None exist in the kit (verified). |
| 18 | **P1** | `UIKit/UIKit.swift` (`UIDevice`) | Make `userInterfaceIdiom` deterministic on web: derive `.phone`/`.pad` from `win_width()/win_height()` aspect (or honor a runtime hint), instead of the static `.unspecified` (`:274`). | `getDeviceSize()` (`GameGlobal.swift:61-85`) → `settings.mode ∈ {1,2,4}` → scene size, HUD/stick offsets, scale. `.unspecified` falls through to `mode=4` (iPhone X, 762×352). The **target mode is a user decision** (Open Q); the kit must at least make it deterministic and overridable. |
| 19 | **P2** | `WasmKit/runtime.js` | Scan `assets/scenes/*.json` and `assets/particles/*.json` so `asset_text`/`asset_exists` resolve them by basename (`level5`, `blackHole`) and `name.json` (the loader probes `name`, `name.json`, `name.sks.json` — `SKSceneLoader.swift:72`). Ensure `wasmweb_manifest` lists them under `texts`. | The runtime already registers names by full path / `assets/`-prefixed / basename / basename-without-ext; just ensure the new dirs are scanned and JSON is treated as text. Low risk. |
| 20 | **P1** | `WasmKit/runtime.js` (font fallback) | Map `'Emulogic'` → `emulogic.ttf` (PostScript name `Emulogic`) and ensure `'Apple Color Emoji'` falls back to the host system emoji font. Today the hardcoded fallback is `JetBrainsMono-Bold/MarkerFelt`. | Nearly every visible element is an emoji `SKLabelNode` in `'Apple Color Emoji'`; numeric/score labels use `'Emulogic'`. Without these in the fallback list the game renders wrong glyphs. |
| 21 | **P2** | `SpriteKit/SKStubs.swift` (`SKTileMapNode.draw`) | Optionally render a live tile map's `SKTileDefinition.textures.first` per cell. | UFO **destroys** the tile map after extracting bodies/emoji (`GameWorld.swift:55-66`); terrain is drawn by spawned emoji/sprite children. The only live tile layer is the dimmed `Water` layer (alpha 0.4). Needed **only** for that layer; flag during Phase 4. |

> **No `include/abi.h` change.** Confirmed against the WasmKit dossier: 2D draw, emoji text, `gfx_set_filter` blur, looping/simultaneous audio, input, and `store_*` persistence all exist. All WasmKit work is `runtime.js` asset/font wiring (#19, #20).

---

## D. Asset conversion pipeline (exact commands)

All conversions run on macOS (sks2json needs real SpriteKit). Output lands in `ufo-emoji-web/web/assets/`.

### D.1 `.sks` scenes/levels/particles → JSON (via the extended sks2json, §C #7)

```bash
SKS2JSON=/Users/toddbruss/Documents/GitHub/SuperBox64Kit/Tools/sks2json
( cd "$SKS2JSON" && swift build -c release )
BIN="$SKS2JSON/.build/release/sks2json"
GAME="/Users/toddbruss/Documents/GitHub/UFOEmoji2020/UFO Emoji/UFO Emoji"
OUT="ufo-emoji-web/web/assets"

# Scenes (GameScene.sks must contain child 'world' → 'Rocky'; GameMenu children: emoji/ship/level/music/sound/play)
"$BIN" "$GAME/GameScene/GameScene.sks" > "$OUT/scenes/GameScene.json"
"$BIN" "$GAME/GameMenu/GameMenu.sks"   > "$OUT/scenes/GameMenu.json"

# 12 real levels (skip strays: level.sks, level__.sks, '* copy*.sks')
for n in $(seq 1 12); do
  "$BIN" "$GAME/GameLevels/level${n}.sks" > "$OUT/scenes/level${n}.json"
done

# 7 used particle emitters (grayParticle.sks is unused — skip)
for p in aura blackHole blueParticle fireParticle magicParticle minigamehole smokeParticle; do
  "$BIN" "$GAME/GameParticles/${p}.sks" > "$OUT/particles/${p}.json"
done
```

**sks2json limits & their UFO impact (verified):** baked `SKAction`s do **not** round-trip — UFO adds all actions in code (OK); only rect/circle physics extracted — UFO's tile bodies are custom polygons built in `GameTimeMapRun` from `userData`, **not** from `.sks` physics (OK, geometry derives from tile names/userData, not `.sks` bodies). **Particle texture dependency (parity risk):** the 7 emitters may reference textures (e.g. `bokeh`, `spark`); #7's `encode()` must emit `particleTexture` (it already does for code-built emitters, `main.swift:187-189`) and those texture PNGs must be in `assets/images/` (see D.2). Verify per-emitter in Phase 4.

### D.2 `.xcassets` atlases → PNG (rasterize PDFs) — **committed load-bearing list**

```bash
# Vector PDFs → PNG @2x (retina parity). Naming must match SKTexture(imageNamed:) / 'atlas/texture' lookups.
rasterize() {  # $1 = imageset dir, $2 = out name
  pdf=$(find "$1" -name '*.pdf' | head -1)
  [ -n "$pdf" ] && sips -s format png "$pdf" --out "$OUT/images/$2.png"
}
```

The plan **commits** to converting these (no longer deferred to "verification"). Every name below is referenced by `SKSpriteNode(imageNamed:)`/`UIImage(named:)`/`SKTexture(imageNamed:)` at runtime (dossier-cross-checked):

- **Ships (GameGUI):** `aliensaucer`, `aliencanape`, `monkeyrocket`, `monkeycanape`, `poopship`, `poopcanape`, `tractorbeam`
- **Lasers (GameGUI):** `laserbeam`, `superlaserbeam` (the game composes `"super"+"laserbeam"` → register both)
- **HUD (GameHUD):** `fire45-right/left/top/btm`, `hud45-right/left/top/btm`
- **Flight stick (GameHUD):** `bg-stick`, `bg-joystick`
- **Backgrounds (Backgrounds):** `waterWorld`, `miniDesert`, `skyMtns`
- **Menu (GameMenu.spriteatlas):** `menu-left`, `menu-right`, `playbutton`, `latestlogo`, `menu-play`
- **Terrain tiles** (for the live `Water` layer + any tile that keeps a texture): grass variants (`grass2-{btm-right,btmleft,topleft,topright,left,right}-{1,2}`), `dirt*`, `stone*`, `gold*`, `straw2-*`, water variants (`Earth-Water*`, `Water{Bottom,Left,Right,Top}`)
- **Effects (GameEffects):** `bokeh.png` (copy as-is), plus any `particleTexture` names emitted by D.1 (e.g. `spark`, `aura`, `blackHole1`)

```bash
cp "$GAME/Assets.xcassets/GameEffects.spriteatlas/bokeh.imageset/bokeh.png" "$OUT/images/bokeh.png"
```

**Bare-name vs atlas resolution (critique fix).** The kit resolves atlas textures as `"atlas/texture"` (`SKTextureAtlas`) **but** the game loads via `SKSpriteNode(imageNamed: "menu-left")` (bare). Resolution: rasterize **every** load-bearing imageset to a **flat `images/<name>.png`** (no atlas prefix) so bare `imageNamed:` lookups hit directly. The runtime registers images by basename/basename-without-ext, so `imageNamed("menu-left")` → `images/menu-left.png`. No atlas-membership reconciliation is needed because we flatten. **Emoji-keyed imagesets** (`Game_placeholders/*`, 652 of them) are **not** converted — the game draws emoji as live `SKLabelNode` text, not sprites.

### D.3 Font → FontFace

```bash
cp "$GAME/GameFonts/emulogic.ttf" "$OUT/fonts/emulogic.ttf"
```

Declared under `fonts` in `manifest.json`; runtime registers via `FontFace`. **Family name must be `Emulogic`** (PostScript name, not filename) to match `SKLabelNode(fontNamed:"Emulogic")` — wired by Kit Change #20. `'Apple Color Emoji'` resolves to the host emoji font via the runtime fallback (#20). Ignore `Toddmoji.otf` (declared in Info.plist, absent, never used in code).

### D.4 Audio `.m4a/.mp3` → web formats — **register under the names the game requests**

The original calls SFX by their **m4a basenames** via `playSoundFileNamed` (verified): `fire.m4a`, `wah2.m4a`, `murrmurr.m4a`, `boomFire2.m4a`, `extralife.m4a`, `doublelaser.m4a`; music via `AVAudioPlayer(... forResource:"music1", withExtension:"mp3")`. Because the game source is unchanged, each asset **must be registered under the exact requested name**. The salvaged files use different names (`boom.wav`, `explosion.wav`, …) — **do not rely on them**; convert the originals 1:1:

```bash
for s in fire wah2 murrmurr boomFire1 boomFire2 Explosion1 extralife doublelaser; do
  ffmpeg -y -i "$GAME/GameSounds/${s}.m4a" "$OUT/sfx/${s}.m4a.wav"   # or keep .m4a if AAC decodes in target browsers
done
ffmpeg -y -i "$GAME/GameMusic/music1.mp3" "$OUT/sfx/music1.mp3.ogg"
```

The runtime registers by basename-with-and-without-ext, so `playSoundFileNamed("fire.m4a")` resolves `fire.m4a` → decoded buffer, and `AVAudioPlayer(... "music1","mp3")` resolves `music1.mp3`. **Keep-`.m4a` vs transcode-to-wav/ogg is a delivery decision (Open Q).** The salvaged `music.ogg`/`*.wav` may be reused only if renamed to the requested names.

---

## E. Build & serve (exact commands)

Restore the salvaged tree, edit `Package.swift` (add UIKit product), extend `build.sh` with the symlink loop (§B.1), `.preCommon` transforms (§B.1), and the sks2json/asset loops (§D).

```bash
cd /Users/toddbruss/Documents/GitHub/UFOEmoji2020
git checkout HEAD -- ufo-emoji-web        # restore salvaged files (tracked, not in working tree)
cd ufo-emoji-web

./build.sh            # debug:   .build/wasm32-unknown-wasip1/debug/UFOEmoji.wasm → web/ufoemoji.wasm
./build.sh release    # release: -Osize -Xlinker -s -disable-reflection-metadata, then wasm-opt -Oz
```

Under the hood (BossMan-style):

```bash
TOOLCHAINS="org.swift.6.3.2-release" xcrun --toolchain swift swift build \
  --swift-sdk swift-6.3.2-RELEASE_wasm -c release \
  -Xswiftc -Osize -Xlinker -s -Xswiftc -Xfrontend -Xswiftc -disable-reflection-metadata
wasm-opt -Oz --enable-bulk-memory --enable-nontrapping-float-to-int \
  --enable-sign-ext --enable-mutable-globals --enable-multivalue \
  .build/.../release/UFOEmoji.wasm -o web/ufoemoji.wasm
source ../../WasmKit/build.sh
wasmweb_manifest web/assets web/manifest.json     # lists fonts/images/sounds/texts
cp ../../WasmKit/runtime.js web/runtime.js
```

Linker flags (from Package.swift): `-mexec-model=reactor`, `--export=boot --export=frame --export-if-defined=_initialize --allow-undefined`; `defaultIsolation(MainActor.self)`.

```bash
cd web && python3 -m http.server 8000   # http://localhost:8000/index.html
```

`web/index.html` sets `window.WASMWEB = {logicalWidth, logicalHeight, wasmUrl:'ufoemoji.wasm', assetRoot:'assets', title:'UFO Emoji'}`. **Set logical size to the boot scene size** (§C #18; e.g. 762×352 for mode 4) so `.aspectFill` letterboxes correctly — Open Q.

---

## F. Parity / verification — proving "matches precisely"

### F.1 Headless (salvaged, unchanged)

- `tools/smoketest.mjs`: instantiate the wasm, feed synthetic SFML key events (57=space fire, 71/72/73/74=arrows for stick), run ~970 frames across phases, assert **no trap** and that `gfx_clear`/`gfx_draw_text`/`snd_play` are called. **Run after every kit change.**
- `tools/shoot.mjs`: Playwright headless Chrome, screenshots title + gameplay after Space + arrows.
- **New gating probe (Phase 2/3):** assert `asset_exists("level5")`, `asset_exists("blackHole")`, `asset_exists("fire.m4a")`, `asset_exists("Emulogic")`, `asset_exists("menu-left")`, `asset_exists("tractorbeam")` all return 1.

### F.2 Per-feature parity matrix (against the iOS original)

| Check | Method | Expected (original constants) |
|---|---|---|
| Boot reaches menu | first `frame()` drains the deferred present | `gameMenu()` presents `GameMenu(fileNamed:)`; menu visible frame 1 |
| `self.view as? SKView` succeeds | log cast result in `gameMenu`/`gameLevel` | non-nil after Kit Change #1 |
| Scene size & anchor | log `scene.size`/`anchorPoint` at boot | mode4 game = 762×352, anchor (1,1); menu 762×352; StartUp/LevelUp (0,0); GameOver (0.5,0.5) — render+touch anchor-aware (#11) |
| Per-node touch | tap flight-stick / fire button regions | stick velocity changes; laser/bomb fires (#10) |
| Flight-stick feel | hold direction; sample velocity/zRotation/frame | clamp ±500, impulse divisors 250/500, damping 40, zRotation = velocity.dx/10·−0.003; tick once/frame via per-frame hook (note dt-clamp caveat below) |
| Level load (all 12) | boot each via menu level toggle; assert tile-spawned emoji > 0 + waypoints seeded | `levelN.json` reconstructs tiles (#7); `//`-search finds layers (#6); `📈`→waypoints (≤145), `👾`→spawns |
| Bezier patrol paths | spawn `👾`; trace follow path | `addQuadCurve` path renders (#4); `SKAction.follow` loops every 10s |
| Field circle body | enter `🛑` region | `arcCenter` edge body present (#4); negative-falloff pull non-trivial (#15) |
| Physics contacts | laser into baddie | `contactTestBitMask=3994`; scoreDict (`🐽`=5…`🤯`=140); tractor ×2, laser ×1 |
| Node copy | fire double/super laser, bomb; parallax tiling | `copy() as! SKSpriteNode` clones texture/body/children (#5) |
| Fields | `💢`/`🛑`/`🎇`/`🌀` | spring/radial/portal pull matches; `🌀` in level 1..3 jumps to 5 |
| Powerups | `🛡 🔫 💠 🔱 🕹 ❣️` | shield blocks death; double/super laser; `❣️` +1 life (cap 9) |
| Audio | fire/bomb/powerup/extralife + looping music | each name resolves (#13 wait-seq); `music1` loops, stops on death/level-up (#14 post-play loop) |
| Tractor glow | enable tractor | `CIMotionBlur` → `gfx_set_filter("blur")` (#12) |
| Visual/emoji | screenshot ship/HUD/lives | emoji via `gfx_set_text_baseline(1)`; `Emulogic` for numbers (#20) |
| Persistence | set high score, reload | `store_*` keys highlevel/highscore/level/emoji survive |
| Lives/progression | die 3×; clear a level | minlives3/maxlives9, maxlevel12, >12 wraps to 1, LevelUp after 3.0s |

### F.3 Side-by-side

Capture the iOS Simulator running the unchanged original at mode-4 size vs the wasm build at the same logical size; diff key frames (title, level 1 start, a contact, game-over). "Matches precisely" = identical layout/scoring/progression. **Documented residual risks:** (a) emoji glyph metrics differ by host font, shifting fontSize-derived hitboxes/visuals; (b) `SKView.tick` clamps dt to 1/60 (`SKView.swift:124`), so on variable-refresh displays the per-frame stick integration / zRotation may diverge slightly from iOS CADisplayLink feel.

---

## G. Phased execution (dependency order)

**Phase 0 — Scaffold (no game logic).**
- Restore `ufo-emoji-web` from `HEAD`; delete old `GameScene.swift` rewrite + generated `runtime.js`/`.wasm`; **edit `Package.swift` to add the UIKit product**; rewrite `main.swift` (GameViewController + global SKView); extend `build.sh` (symlink loop, `.preCommon` for AppDelegate/GTFlightYoke/GameViewController, sks2json + asset loops); add the two compat shims.
- Done-check: `swift build` reaches the game files (fails only on missing kit APIs, not packaging or `weak`/`@objc`/`@UIApplicationMain`).

**Phase 1 — Kit P0 compile-blockers (parallel fan-out). Must clear EVERY P0 in §C before "compiles clean."** Subagents:
- *Agent A* — #1 `SKView` as `UIView` + props; #3 `showsLargeContentViewer`; #2 `UIViewController` override surface + `UIInterfaceOrientationMask`/`UIRectEdge`.
- *Agent B* — #4 `NSBezierPath` curve/arc (+ `CGMutablePath.addQuadCurve` if missing); #5 `SKNode/SKSpriteNode.copy()`; #6 `childNode("//")`.
- *Agent C* — #7 (sks2json + loader tile case + userData) and #8 (`SKTileMapNode` API: `tileDefinition`, settable `tileSize`, `SKTileGroup.empty()`, `setTileGroup(_:andTileDefinition:…)`); #16 failable `SKReferenceNode(fileNamed:)`.
- *Agent D* — #9 `applicationState`; #9b `LaunchOptionsKey`; #12 `CIFilter` parameter type; #17 UIGraphics/Photos shims.
- Done-check: `swift build` of `ufo-emoji-web` **compiles clean** (14 files + 2 shims + main). This is now reachable because v1's missing blockers (#1,#2,#3,#4,#5,#6,#12,#16,#17,#9b) are all included.

**Phase 2 — Asset pipeline (depends on Phase 1 #7,#8).** Subagents:
- *Agent E* — run §D.1 (sks2json), commit JSON.
- *Agent F* — run §D.2 (the **committed** load-bearing PNG list) + §D.3 (font), commit images/font.
- *Agent G* — run §D.4 audio name-mapping, commit sfx.
- Done-check: the new `asset_exists` probe (§F.1) is all-green; manifest regenerated.

**Phase 3 — Loader + runtime wiring (depends on Phase 2).**
- #19 runtime scene/particle JSON registration; #20 emoji/Emulogic font fallback. Verify `GameWorld.gameLevel("level1")` returns a populated world (tile-spawned emoji + waypoints), and `smoketest.mjs` passes (no trap; draw+sound calls observed).

**Phase 4 — Gameplay parity tuning (depends on Phase 3). Filed as kit tuning tickets — never game edits.** Subagents:
- *Agent H* — #10 per-node touch dispatch (stick + fire buttons live); #11 anchorPoint-aware render+touch.
- *Agent I* — #13 `playSoundFileNamed` wait-seq; #14 AVAudioPlayer post-play loop; #15 negative-falloff field math against `💢/🛑/🎇/🌀` feel.
- *Agent J* — run §F.2 contact/score/lives/progression matrix across all 12 levels; #12 tractor `CIMotionBlur` glow; #21 live-`Water`-layer tile texture; emoji baseline; parallax depth 0.334; z-order. Verify particle texture deps from D.1.
- Done-check: §F.2 matrix green; `shoot.mjs` matches the iOS reference at the chosen mode size.

**Phase 5 — Release & serve.**
- `./build.sh release` → `web/ufoemoji.wasm` (wasm-opt -Oz); `index.html` boots menu → play → level → death/level-up loop end-to-end; high score persists across reload. `git commit` after a successful `xcf build`/release per repo convention.

## Kit Changes Required

| File in SuperBox64Kit / WasmKit | Feature to add | Why |
|---|---|---|
| `Sources/SpriteKit/SKView.swift` (+ relocate `UIView`/`UIResponder` base into SpriteKit, re-export from UIKit) | Make `SKView` a `UIView` subclass (drop `final`); add `isMultipleTouchEnabled`, `isOpaque`, `clipsToBounds`, `backgroundColor`, `showsLargeContentViewer` | `GameViewController.swift:45,82` `self.view as? SKView` is structurally impossible today (`view: UIView`, `SKView` not a `UIView`) → no scene presents; `:107-113` set view props absent from `SKView` |
| `Sources/UIKit/UIKit.swift` (`UIViewController`) | `shouldAutorotate`, `supportedInterfaceOrientations`, `preferredScreenEdgesDeferringSystemGestures`, `prefersHomeIndicatorAutoHidden`, `prefersStatusBarHidden`, `didReceiveMemoryWarning` + types `UIInterfaceOrientationMask`, `UIRectEdge` | `GameViewController.swift:117-138` overrides all six; each is "does not override" today; supporting OptionSet types absent |
| `Sources/AppKit/AppKit.swift` (`NSBezierPath` = `UIBezierPath`) | `addQuadCurve(to:controlPoint:)`, `addCurve(...)`, `init(arcCenter:radius:startAngle:endAngle:clockwise:)` (+ `CGMutablePath.addQuadCurve` if absent) | `GameBadGuyAI.swift:132-138` (8× quad-curve patrol paths) and `GameTimeMapRun.swift:353` (arc circle body); both hard compile errors |
| `Sources/SpriteKit/SKNode.swift`, `SKSpriteNode.swift` | `copy() -> Self` deep copy (transform/children/userData; sprite texture/size/anchor/color/physicsBody) supporting `copy() as! SKSpriteNode` | `GameParallax.swift:48`, `GameScene.swift:1991,2011,2068`; compile + force-cast crash path |
| `Sources/SpriteKit/SKNode.swift` (`childNode(withName:)`) | Honor leading `//` recursive descendant search | `GameWorld.swift:43` `childNode(withName:"//"+name)`; flat match returns nil → no level loads |
| `Sources/SpriteKit/SKScene.swift` (touch entry points) | Node-level touch dispatch: hit-test tree, deliver to deepest `isUserInteractionEnabled` node's `touchesBegan/Moved/Ended` | Kit routes touches only to scene (`SKView.swift:161-163`); `GTFlightYoke` + HUD fire buttons are interactive `SKNode`s — dead otherwise |
| `Sources/SpriteKit/SKView.swift` + `SKScene.swift` | Honor `scene.anchorPoint` in `render` and touch→scene coordinate conversion | `SKView.render` ignores `anchorPoint`; game uses `(1,1)` gameplay / `(0,0)` / `(0.5,0.5)` → whole layout/touch/bounds shifted |
| `Tools/sks2json/main.swift` | Emit `SKTileMapNode` (tileSize/cols/rows + per-cell definitionName/name/userData/flip/textures) and `physicsBody` (rect/circle) | `encode()` covers only Scene/Sprite/Label/Shape/Emitter; UFO level geometry + AI live in tile `userData`/names |
| `Sources/SpriteKit/SKSceneLoader.swift` | `case "SKTileMapNode"` in `build(from:)`; rehydrate cell `SKTileDefinition` + `userData`/`name`; apply `userData` in `applyCommonProps` | `default` collapses tile maps to bare `SKNode`; `userData` never applied today |
| `Sources/SpriteKit/SKStubs.swift` (`SKTileMapNode`/`SKTileGroup`) | `tileDefinition(atColumn:row:)`; make `tileSize` settable; `SKTileGroup.empty()`; `setTileGroup(_:andTileDefinition:forColumn:row:)` | `GameWorld.setupLevel` (`GameWorld.swift:83-96`) calls all four; missing (`tileSet`/`SKTileSet.init()` already exist — not gaps) |
| `Sources/SpriteKit/SKStubs.swift` (`SKReferenceNode`) | Failable `convenience init?(fileNamed:)` routing through `SKSceneLoader.loadNode` | `GameWorld.swift:31` `guard var ref = SKReferenceNode(fileNamed:…)`; standalone init is non-failable |
| `Sources/UIKit/UIKit.swift` (`UIApplication`) | `UIApplicationState` enum + `applicationState` (default `.active`); `LaunchOptionsKey` type | `GameScene.swift:967` switches on `applicationState`; `AppDelegate.swift:16` uses `LaunchOptionsKey` in signature |
| `Sources/UIKit/UIKit.swift` (UIGraphics + Photos) | `UIGraphicsBeginImageContextWithOptions`, `UIGraphicsGetImageFromCurrentImageContext`, `UIGraphicsEndImageContext`, `UIImageWriteToSavedPhotosAlbum`, `UIView.drawHierarchy(in:afterScreenUpdates:)` (no-ops) | `GameScene.swift:636-640` (demo screenshot); dead at runtime but unconditional code must compile |
| `Sources/SpriteKit/SKStubs.swift` (`CIFilter`) + `SKEffectNode` | Change `init?(name:parameters:)` to accept `[String:CGFloat]?`/`[String:Any]?`; recognize `CIMotionBlur` (`inputRadius`/`inputAngle`) → `gfx_set_filter("blur(Npx)")` | `Extensions.swift:15` passes a mixed-type dict that won't coerce to `[String:Double]` — a P0 compile error |
| `Sources/UIKit/UIKit.swift` (`UIDevice`) | Deterministic `userInterfaceIdiom` (derive `.phone`/`.pad` from aspect, or runtime hint) | `GameGlobal.swift:61-85` `getDeviceSize()` → `settings.mode` → size/HUD/scale; `.unspecified` is non-deterministic |
| `Sources/SpriteKit/SKExtras.swift` (`playSoundFileNamed`) | Honor `waitForCompletion` via clip-length sequencing (already exists; ignores `wait`) | `GameScene.swift` chains on completion; early-firing breaks sequence timing |
| `Sources/AVFoundation/AVFoundation.swift` (`AVAudioPlayer`) | Make `numberOfLoops` live when set after `play()` (re-tag/restart the voice) | `GameScene.swift:953,1767` set loop after `play()`; loop is bound only at `play()` time (`:87`) |
| `Sources/SpriteKit/SKPhysics.swift` (field models) | Support **negative falloff** for radial/spring fields (full `pow(dist,falloff)`); tune to UFO strengths | `applyFields` (`:656`) only attenuates when `falloff>0`; `🛑` portal `falloff=-0.05` is a no-op → wrong feel |
| `WasmKit/runtime.js` | Scan `assets/scenes/*.json` + `assets/particles/*.json` (register basename + `.json`) under `texts` | Loader probes `name`/`name.json`; new dirs must be scanned |
| `WasmKit/runtime.js` (font fallback) | Map `'Emulogic'`→`emulogic.ttf`; `'Apple Color Emoji'`→host emoji font | Every emoji/score label depends on these; default fallback is JetBrainsMono/MarkerFelt |
| `Sources/SpriteKit/SKStubs.swift` (`SKTileMapNode.draw`) — P2 | Optionally render `SKTileDefinition.textures.first` per cell | Only the live dimmed `Water` layer (alpha 0.4) needs it; rest of terrain is spawned emoji/sprites |

## Open Questions

1. **Target device mode** (drives scene size, HUD/stick offsets, scale via `getDeviceSize()`): ship mode **4** (iPhone X, 762×352), mode **2** (iPhone, 626×352), or mode **1** (iPad)? This sets both `UIDevice.userInterfaceIdiom` (Kit Change #18) and `WASMWEB.logicalWidth/Height` in `index.html`, which must match for `.aspectFill` letterboxing to match the iOS reference.
2. **Audio delivery format**: keep `.m4a` (AAC plays in Chrome/Safari, fails in some Firefox) or transcode SFX/music to `.wav`/`.ogg` for universal browser support? Affects D.4 and bundle size (music1 is ~7 MB).
3. **Emoji rendering fidelity acceptance**: host-font emoji substitution changes glyph metrics, which shift fontSize-derived collision hitboxes and visual layout vs the iOS original. Is documented near-parity acceptable, or is pixel-exact emoji required (would need bundling Apple Color Emoji, a licensing question)?

## Assumptions

- The salvaged `ufo-emoji-web` tree at git `HEAD` (`33ffdcf`) is authoritative for `Package.swift`/`Package.resolved`/`build.sh`/`index.html`/test harness; it is restored via `git checkout HEAD -- ufo-emoji-web` before edits (the files are tracked but not in the working tree).
- The kit relocation of a minimal `UIView`/`UIResponder` base into the SpriteKit module (to let `SKView: UIView` without inverting the `UIKit→SpriteKit` package dependency) is acceptable; UIKit re-exports them via `typealias` so existing UIKit-importing games are unaffected.
- `.preCommon` mechanical rewrites of exactly three files (AppDelegate `@UIApplicationMain`/LaunchOptionsKey usage, GTFlightYoke `@objc`/`#selector`/CADisplayLink, GameViewController `[weak view]`) count as "unchanged originals" under the prime directive, mirroring BossMan's documented `.wasm-backups/*.preCommon` pattern — the on-disk originals are never modified.
- The 12 real levels are `level1.sks`…`level12.sks`; the strays (`level.sks`, `level__.sks`, `*copy*.sks`) and `grayParticle.sks`, `music2.m4a`, `boomFire1.m4a`, `Explosion1.m4a` are unused and excluded.
- `CGMutablePath` provides `addArc` and either `addQuadCurve` or `addCurve` for the Bezier work (dossier lists `addArc`/`addCurve`); if `addQuadCurve` is absent it is added in Kit Change #4.
- sks2json on macOS can unarchive UFO's `.sks` tile data through real SpriteKit (required for #7); particle `.sks` round-trip emits `particleTexture` names whose PNGs are present in `assets/images/`.
- `KitRunLoop` exposes a per-frame hook (`addPerFrameHook`, dossier-referenced via `GameController.swift:63`/`FoundationShims.swift`) usable by `UFOInputCompat` to replace `CADisplayLink`; if the exact symbol differs, the shim adapts to the available hook.
- Single-threaded wasm event loop makes the `[weak view]`→`[view]` strong-capture rewrite safe (no retain cycle; closure runs same-frame).