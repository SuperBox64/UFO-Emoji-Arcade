import SpriteKit
import UIKit
import KitABI

// Reactor-mode wasm entry. WasmKit's runtime.js calls _initialize once after the
// asset manifest preloads, then boot() brings up the SKView + first scene exactly
// as the iOS GameViewController does, and frame() advances one animation frame.
//
// The original boot path is GameViewController.viewDidLoad() → gameMenu(), which
// does `self.view as? SKView`. We construct a real GameViewController, assign its
// .view to an SKView (legal once SKView is a UIView subclass — SuperBox64Kit), and
// drive viewDidLoad(); we also hold the SKView so frame() can tick it regardless.

nonisolated(unsafe) var gvc: GameViewController? = nil
nonisolated(unsafe) var gView: SKView? = nil

private func bootBody() {
    // AppDelegate.application(_:didFinishLaunchingWithOptions:) normally does
    // this on iOS, but AppDelegate is excluded from the wasm build (its
    // @UIApplicationMain entry conflicts with our boot() reactor entry), so we
    // load persisted settings here before bringing up the first scene.
    loadSettings()
    let v = SKView()
    let c = GameViewController()
    c.view = v
    gView = v
    gvc = c
#if BENCHMARK_LEVEL1
    // Benchmark build: skip GameMenu and boot straight into gameplay level 1
    // (settings.level defaults to 1, clamped >=1 in loadSettings), so "rest"
    // measures real game-logic compute instead of the near-idle menu. We
    // replicate only viewDidLoad()'s non-menu setup (gameDelegate) then jump to
    // the level scene via runGameLevel() → gameLevel() → GameScene → level1.
    gameDelegate = c
    c.runGameLevel()
#else
    c.viewDidLoad()        // → gameDelegate = self; saveSettings(); gameMenu()
#endif
}

// Single-threaded wasm, fully nonisolated stack — call directly.
@_cdecl("boot")  public func boot() { bootBody() }
@_cdecl("frame") public func frame(_ dtMs: Double) { gView?.tick(dtMs) }
