import SpriteKit
import KitABI

// Reactor-mode wasm entry. WasmKit's runtime.js calls _initialize once after
// the asset manifest preloads, then boot() brings up the SKView and the first
// scene (the same construction the iOS GameViewController performs), and
// frame() advances one animation frame per requestAnimationFrame.
//
// Logical canvas is 1280x720 (16:9). GameScene.scaleMode = .aspectFill matches
// the original game's full-bleed layout across phone/tablet/desktop ratios.

nonisolated(unsafe) var view: SKView? = nil

private func bootBody() {
    let v = SKView()
    v.ignoresSiblingOrder = true
    v.showsFPS = false
    v.shouldCullNonVisibleNodes = true
    v.allowsTransparency = true
    v.preferredFramesPerSecond = 60

    let scene = GameScene(size: CGSize(width: 1280, height: 720))
    scene.scaleMode = .aspectFill
    v.presentScene(scene)
    view = v
}

#if hasFeature(Embedded)
@_cdecl("boot")
public func boot() { bootBody() }

@_cdecl("frame")
public func frame(_ dtMs: Double) { view?.tick(dtMs) }
#else
@_cdecl("boot")
public func boot() { MainActor.assumeIsolated { bootBody() } }

@_cdecl("frame")
public func frame(_ dtMs: Double) { MainActor.assumeIsolated { view?.tick(dtMs) } }
#endif
