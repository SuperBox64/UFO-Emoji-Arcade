//
//  GameScene.swift  —  UFO Emoji (WebAssembly edition)
//
//  A code-driven reimplementation of Todd Bruss' iOS SpriteKit game "UFO Emoji"
//  for the SuperBox64 SpriteKit-on-wasm runtime. The original is built from
//  binary .sks scenes + SKTileMapNode tilemaps (which the wasm subset doesn't
//  load), so the side-scrolling arcade gameplay is rebuilt here in pure code,
//  with every actor drawn as live emoji text via SKLabelNode.
//
//  Faithful to the original's identity: pilot an emoji flying saucer (👽🛸 /
//  🐵🚀 / 💩🚀) through three worlds — Water World 🌊, Sand Dunes 🏜️ and Outer
//  Space 🌌 — blasting enemy emoji, grabbing power-ups (double laser, shield,
//  smart bomb, rapid fire, extra life), and chasing a high score across 12
//  levels with boss fights.
//
//  Original game (c) 2015–2024 Todd Bruss. WASM port keeps the gameplay design.
//

import SpriteKit
import GameController

// MARK: - Tunables

private let kSceneW: CGFloat = 1280
private let kSceneH: CGFloat = 720
private let kEmojiFont = "Apple Color Emoji"   // runtime maps to the platform emoji font
private let kArcadeFont = "Menlo-Bold"         // HUD / banners

private enum Z {
    static let bgFar: CGFloat   = -100
    static let bgMid: CGFloat   = -80
    static let bgNear: CGFloat  = -60
    static let world: CGFloat   = 0
    static let item: CGFloat    = 10
    static let enemy: CGFloat   = 20
    static let bullet: CGFloat  = 30
    static let hero: CGFloat    = 40
    static let fx: CGFloat      = 60
    static let hud: CGFloat     = 1000
    static let overlay: CGFloat = 2000
}

// MARK: - Game state machine

private enum Mode {
    case title, ready, playing, levelUp, gameOver
}

// MARK: - Pilots

private struct Pilot {
    let face: String      // 👽 / 🐵 / 💩
    let ship: String      // 🛸 / 🚀
    let beam: String      // laser glyph
    let name: String
}

private let kPilots: [Pilot] = [
    Pilot(face: "👽", ship: "🛸", beam: "🟢", name: "ALIEN"),
    Pilot(face: "🐵", ship: "🚀", beam: "🟡", name: "MONKEY"),
    Pilot(face: "💩", ship: "🚀", beam: "🟤", name: "POO"),
]

// MARK: - World themes

private struct World {
    let name: String
    let sky: SKColor
    let horizon: SKColor
    let far: [String]      // slow parallax emoji
    let near: [String]     // ground / decoration emoji
    let enemies: [String]  // enemy roster for this world
    let goodies: [String]  // friendly critters that drift by for bonus points
}

private let kWorlds: [World] = [
    // Water World  (levels 1–4)
    World(name: "WATER WORLD",
          sky: SKColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1),
          horizon: SKColor(red: 0.05, green: 0.22, blue: 0.55, alpha: 1),
          far: ["☁️", "⛅️", "☁️"],
          near: ["🌊", "🌊", "🏝️", "🌊", "⛵️"],
          enemies: ["🦖", "🐍", "🦅", "🦂", "🐙", "🦈"],
          goodies: ["🐬", "🐢", "🕊", "🦆", "🦋"]),
    // Sand Dunes  (levels 5–8)
    World(name: "SAND DUNES",
          sky: SKColor(red: 0.98, green: 0.78, blue: 0.40, alpha: 1),
          horizon: SKColor(red: 0.80, green: 0.45, blue: 0.18, alpha: 1),
          far: ["☁️", "🌤️", "☁️"],
          near: ["🌵", "🏜️", "🌵", "🪨", "🐫"],
          enemies: ["🦂", "🐗", "🐍", "🦅", "🦖", "👹"],
          goodies: ["🐪", "🦔", "🦎", "🕊", "🌻"]),
    // Outer Space  (levels 9–12)
    World(name: "OUTER SPACE",
          sky: SKColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1),
          horizon: SKColor(red: 0.10, green: 0.04, blue: 0.20, alpha: 1),
          far: ["✨", "⭐️", "🌟", "💫"],
          near: ["🪐", "🌑", "☄️", "🛰️", "🌌"],
          enemies: ["👾", "👽", "🤖", "🛸", "👹", "💀"],
          goodies: ["🌟", "🚀", "🦄", "🪐", "🌈"]),
]

private func worldIndex(forLevel level: Int) -> Int {
    switch level {
    case ...4:  return 0
    case 5...8: return 1
    default:    return 2
    }
}

// MARK: - Power-ups

private enum PowerKind: CaseIterable {
    case doubleLaser, shield, rapidFire, smartBomb, extraLife, bonus
    var glyph: String {
        switch self {
        case .doubleLaser: return "🔫"
        case .shield:      return "🛡"
        case .rapidFire:   return "💠"
        case .smartBomb:   return "🔱"
        case .extraLife:   return "❣️"
        case .bonus:       return "💎"
        }
    }
}

// MARK: - Lightweight actor records (manual movement + AABB collision)

private final class Enemy {
    let node: SKLabelNode
    var vx: CGFloat
    var vy: CGFloat
    var baseY: CGFloat
    var phase: CGFloat
    var wobble: CGFloat
    var hp: Int
    var points: Int
    var radius: CGFloat
    var fireCooldown: CGFloat
    var isBoss: Bool
    var diving: Bool = false
    init(node: SKLabelNode, vx: CGFloat, vy: CGFloat, baseY: CGFloat, phase: CGFloat,
         wobble: CGFloat, hp: Int, points: Int, radius: CGFloat, fireCooldown: CGFloat, isBoss: Bool) {
        self.node = node; self.vx = vx; self.vy = vy; self.baseY = baseY
        self.phase = phase; self.wobble = wobble; self.hp = hp; self.points = points
        self.radius = radius; self.fireCooldown = fireCooldown; self.isBoss = isBoss
    }
}

private final class Bullet {
    let node: SKLabelNode
    var vx: CGFloat
    var vy: CGFloat
    var radius: CGFloat
    init(node: SKLabelNode, vx: CGFloat, vy: CGFloat, radius: CGFloat) {
        self.node = node; self.vx = vx; self.vy = vy; self.radius = radius
    }
}

private final class Item {
    let node: SKLabelNode
    let kind: PowerKind
    var vx: CGFloat
    var vy: CGFloat
    var phase: CGFloat
    init(node: SKLabelNode, kind: PowerKind, vx: CGFloat, vy: CGFloat, phase: CGFloat) {
        self.node = node; self.kind = kind; self.vx = vx; self.vy = vy; self.phase = phase
    }
}

private final class Drifter {            // friendly goodie critter
    let node: SKLabelNode
    var vx: CGFloat
    var baseY: CGFloat
    var phase: CGFloat
    init(node: SKLabelNode, vx: CGFloat, baseY: CGFloat, phase: CGFloat) {
        self.node = node; self.vx = vx; self.baseY = baseY; self.phase = phase
    }
}

// MARK: - GameScene

final class GameScene: SKScene {

    // World / camera
    private let world = SKNode()          // gameplay actors live here
    private let hud = SKNode()            // screen-fixed HUD
    private let overlay = SKNode()        // banners / menus

    // Hero
    private var hero = SKLabelNode()
    private var heroFace = SKLabelNode()
    private var heroPos = CGPoint(x: 220, y: kSceneH / 2)
    private var heroVel = CGVector.zero
    private let heroRadius: CGFloat = 34

    // Actors
    private var enemies: [Enemy] = []
    private var bullets: [Bullet] = []      // hero shots
    private var enemyShots: [Bullet] = []
    private var items: [Item] = []
    private var drifters: [Drifter] = []
    private var bgLayers: [(node: SKNode, factor: CGFloat)] = []

    // HUD labels
    private var scoreLabel = SKLabelNode()
    private var hiScoreLabel = SKLabelNode()
    private var levelLabel = SKLabelNode()
    private var livesLabel = SKLabelNode()
    private var powerLabel = SKLabelNode()

    // State
    private var mode: Mode = .title
    private var pilotIndex = 0
    private var score = 0
    private var hiScore = 0
    private var level = 1
    private var lives = 3
    private var killsThisLevel = 0
    private var killsNeeded = 10
    private var nextExtraLifeAt = 5000

    // Power-up timers / flags
    private var doubleLaser = false
    private var rapidFire = false
    private var shieldTime: CGFloat = 0

    // Firing / spawning timers
    private var fireTimer: CGFloat = 0
    private var spawnTimer: CGFloat = 0
    private var drifterTimer: CGFloat = 0
    private var bossActive = false

    // Timing
    private var lastUpdate: TimeInterval = 0
    private var stateTimer: CGFloat = 0     // generic per-state countdown

    // Input
    private var keyLeft = false, keyRight = false, keyUp = false, keyDown = false
    private var keyFire = false
    private var spaceEdge = false           // for menu "press space" debouncing

    // Virtual joystick (touch / mouse)
    private var stickActive = false
    private var stickAnchor = CGPoint.zero
    private var stickCurrent = CGPoint.zero
    private var touchFiring = false

    // Gamepad
    private var pad: GCExtendedGamepad?

    // Background music (looping; the runtime resumes audio on first user gesture)
    private var music: SKAudioNode?

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint.zero
        backgroundColor = kWorlds[0].sky

        addChild(world)
        addChild(hud)
        addChild(overlay)
        hud.zPosition = Z.hud
        overlay.zPosition = Z.overlay

        hiScore = UserDefaults.standard.integer(forKey: "ufo.hiscore")

        buildHUD()
        buildHero()
        setupController()
        buildBackground(for: 0)
        startMusic()
        showTitle()
    }

    private func startMusic() {
        let m = SKAudioNode(fileNamed: "music.ogg")
        m.autoplayLooped = true
        m.volume = 0.35
        addChild(m)
        music = m
    }

    // MARK: Background / parallax

    private func clearBackground() {
        for layer in bgLayers { layer.node.removeFromParent() }
        bgLayers.removeAll()
    }

    private func buildBackground(for worldIdx: Int) {
        clearBackground()
        let w = kWorlds[worldIdx]
        backgroundColor = w.sky

        // Sky gradient: a stack of translucent horizon bands rising from the
        // bottom — cheap vertical gradient without a shader.
        let grad = SKNode()
        grad.zPosition = Z.bgFar - 1
        let bands = 14
        for i in 0..<bands {
            let t = CGFloat(i) / CGFloat(bands - 1)
            let band = SKSpriteNode(color: mix(w.sky, w.horizon, t),
                                    size: CGSize(width: kSceneW, height: kSceneH / CGFloat(bands) + 2))
            band.anchorPoint = CGPoint(x: 0, y: 0)
            band.position = CGPoint(x: 0, y: kSceneH / CGFloat(bands) * CGFloat(bands - 1 - i))
            grad.addChild(band)
        }
        world.addChild(grad)
        bgLayers.append((grad, 0))

        // Far layer — slow drifting clouds / stars.
        let far = SKNode()
        far.zPosition = Z.bgFar
        for i in 0..<10 {
            let g = w.far[i % w.far.count]
            let n = makeEmoji(g, size: CGFloat.random(in: 40...72))
            n.position = CGPoint(x: CGFloat(i) / 10 * (kSceneW + 200) + CGFloat.random(in: -40...40),
                                 y: CGFloat.random(in: kSceneH * 0.45 ... kSceneH * 0.95))
            n.alpha = 0.85
            far.addChild(n)
        }
        world.addChild(far)
        bgLayers.append((far, 0.15))

        // Mid layer — bigger scenery.
        let mid = SKNode()
        mid.zPosition = Z.bgMid
        for i in 0..<8 {
            let g = w.near[i % w.near.count]
            let n = makeEmoji(g, size: CGFloat.random(in: 54...96))
            n.position = CGPoint(x: CGFloat(i) / 8 * (kSceneW + 240) + CGFloat.random(in: -40...40),
                                 y: CGFloat.random(in: kSceneH * 0.10 ... kSceneH * 0.40))
            n.alpha = 0.9
            mid.addChild(n)
        }
        world.addChild(mid)
        bgLayers.append((mid, 0.4))

        // Near ground strip scrolling fastest.
        let near = SKNode()
        near.zPosition = Z.bgNear
        for i in 0..<14 {
            let g = w.near[(i + 2) % w.near.count]
            let n = makeEmoji(g, size: CGFloat.random(in: 46...74))
            n.position = CGPoint(x: CGFloat(i) / 14 * (kSceneW + 200),
                                 y: CGFloat.random(in: 24...90))
            near.addChild(n)
        }
        world.addChild(near)
        bgLayers.append((near, 0.85))
    }

    private func scrollBackground(_ dt: CGFloat) {
        let base: CGFloat = 90
        for layer in bgLayers where layer.factor > 0 {
            let dx = base * layer.factor * dt
            for child in layer.node.children {
                child.position.x -= dx
                if child.position.x < -120 {
                    child.position.x += kSceneW + 220 + CGFloat.random(in: 0...120)
                    child.position.y = layer.factor > 0.6
                        ? CGFloat.random(in: 24...100)
                        : CGFloat.random(in: kSceneH * 0.12 ... kSceneH * 0.95)
                }
            }
        }
    }

    // MARK: Hero

    private func buildHero() {
        hero.removeFromParent()
        heroFace.removeFromParent()
        let p = kPilots[pilotIndex]

        hero = makeEmoji(p.ship, size: 62)
        hero.zPosition = Z.hero
        hero.name = "hero"

        heroFace = makeEmoji(p.face, size: 30)
        heroFace.zPosition = Z.hero + 1
        heroFace.position = CGPoint(x: 6, y: 2)   // riding in the saucer
        hero.addChild(heroFace)

        hero.position = heroPos
        world.addChild(hero)
        hero.isHidden = true
    }

    private func refreshHeroPilot() {
        let p = kPilots[pilotIndex]
        hero.text = p.ship
        heroFace.text = p.face
    }

    // MARK: HUD

    private func buildHUD() {
        scoreLabel = arcadeLabel(size: 26, align: .left)
        scoreLabel.position = CGPoint(x: 24, y: kSceneH - 40)
        hud.addChild(scoreLabel)

        hiScoreLabel = arcadeLabel(size: 20, align: .center)
        hiScoreLabel.position = CGPoint(x: kSceneW / 2, y: kSceneH - 36)
        hud.addChild(hiScoreLabel)

        levelLabel = arcadeLabel(size: 20, align: .center)
        levelLabel.position = CGPoint(x: kSceneW / 2, y: kSceneH - 62)
        hud.addChild(levelLabel)

        livesLabel = makeEmoji("", size: 30, align: .right)
        livesLabel.position = CGPoint(x: kSceneW - 24, y: kSceneH - 44)
        hud.addChild(livesLabel)

        powerLabel = makeEmoji("", size: 26, align: .left)
        powerLabel.position = CGPoint(x: 24, y: kSceneH - 74)
        hud.addChild(powerLabel)

        updateHUD()
    }

    private func updateHUD() {
        scoreLabel.text = "SCORE \(score)"
        hiScoreLabel.text = "HI \(max(hiScore, score))"
        levelLabel.text = "LEVEL \(level)  ·  \(kWorlds[worldIndex(forLevel: level)].name)"
        let face = kPilots[pilotIndex].face
        livesLabel.text = String(repeating: face, count: max(0, min(lives, 6)))
        var p = ""
        if doubleLaser { p += "🔫" }
        if rapidFire { p += "💠" }
        if shieldTime > 0 { p += "🛡" }
        powerLabel.text = p
    }

    // MARK: Menus / banners

    private func showTitle() {
        mode = .title
        hero.isHidden = true
        clearOverlay()

        let title = makeEmoji("🛸 UFO EMOJI 👽", size: 64, align: .center)
        title.position = CGPoint(x: kSceneW / 2, y: kSceneH * 0.72)
        title.run(.repeatForever(.sequence([
            .scale(to: 1.06, duration: 0.8),
            .scale(to: 1.0, duration: 0.8),
        ])))
        overlay.addChild(title)

        addOverlayText("AN EMOJI ARCADE SHOOTER", size: 22, y: kSceneH * 0.60)

        let p = kPilots[pilotIndex]
        let pilotLine = makeEmoji("PILOT:  \(p.ship)\(p.face)  \(p.name)", size: 30, align: .center)
        pilotLine.name = "pilotLine"
        pilotLine.position = CGPoint(x: kSceneW / 2, y: kSceneH * 0.48)
        overlay.addChild(pilotLine)

        addOverlayText("[1] [2] [3] OR TAP THE PILOT TO SWITCH", size: 16, y: kSceneH * 0.40)
        addOverlayText("MOVE: ARROWS / WASD / DRAG   ·   FIRE: SPACE / HOLD", size: 16, y: kSceneH * 0.32)

        let start = arcadeLabel(size: 26, align: .center)
        start.text = "PRESS SPACE  ·  TAP TO START"
        start.position = CGPoint(x: kSceneW / 2, y: kSceneH * 0.18)
        start.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6),
        ])))
        overlay.addChild(start)

        updateHUD()
    }

    private func refreshPilotLine() {
        guard let line = overlay.childNode(withName: "pilotLine") as? SKLabelNode else { return }
        let p = kPilots[pilotIndex]
        line.text = "PILOT:  \(p.ship)\(p.face)  \(p.name)"
    }

    private func startNewGame() {
        score = 0
        lives = 3
        level = 1
        nextExtraLifeAt = 5000
        refreshHeroPilot()
        beginLevel()
    }

    private func beginLevel() {
        clearActors()
        clearOverlay()
        doubleLaser = false
        rapidFire = false
        shieldTime = 0
        killsThisLevel = 0
        killsNeeded = 8 + level * 2
        bossActive = false
        spawnTimer = 1.0
        drifterTimer = 2.0
        buildBackground(for: worldIndex(forLevel: level))
        heroPos = CGPoint(x: 220, y: kSceneH / 2)
        heroVel = .zero
        hero.position = heroPos
        hero.zRotation = 0
        hero.isHidden = false
        hero.alpha = 1
        updateHUD()

        // Ready · Set · Go traffic light (StartUp.swift homage)
        mode = .ready
        stateTimer = 0
        runReadySetGo()
    }

    private func runReadySetGo() {
        let light = makeEmoji("🔴", size: 96, align: .center)
        light.position = CGPoint(x: kSceneW / 2, y: kSceneH / 2)
        light.name = "rsg"
        overlay.addChild(light)

        let word = arcadeLabel(size: 34, align: .center)
        word.text = "READY"
        word.position = CGPoint(x: kSceneW / 2, y: kSceneH / 2 - 90)
        word.name = "rsgWord"
        overlay.addChild(word)

        light.run(.sequence([
            .wait(forDuration: 0.7),
            .run { [weak self] in light.text = "🟡"; (self?.overlay.childNode(withName: "rsgWord") as? SKLabelNode)?.text = "SET" },
            .wait(forDuration: 0.7),
            .run { [weak self] in light.text = "🟢"; (self?.overlay.childNode(withName: "rsgWord") as? SKLabelNode)?.text = "GO!" },
            .wait(forDuration: 0.6),
            .run { [weak self] in
                self?.overlay.childNode(withName: "rsg")?.removeFromParent()
                self?.overlay.childNode(withName: "rsgWord")?.removeFromParent()
                self?.mode = .playing
            },
        ]))
    }

    private func completeLevel() {
        mode = .levelUp
        bossActive = false
        clearOverlay()
        let banner = arcadeLabel(size: 48, align: .center)
        banner.text = "LEVEL \(level) CLEAR!"
        banner.position = CGPoint(x: kSceneW / 2, y: kSceneH / 2)
        overlay.addChild(banner)
        banner.run(.sequence([
            .scale(to: 1.2, duration: 0.4),
            .scale(to: 1.0, duration: 0.4),
            .wait(forDuration: 0.7),
            .run { [weak self] in
                guard let self else { return }
                if self.level >= 12 {
                    self.victory()
                } else {
                    self.level += 1
                    self.beginLevel()
                }
            },
        ]))
    }

    private func victory() {
        mode = .gameOver
        clearActors()
        clearOverlay()
        commitHiScore()
        addOverlayText("🏆 YOU SAVED THE GALAXY! 🏆", size: 46, y: kSceneH * 0.62)
        addOverlayText("FINAL SCORE  \(score)", size: 30, y: kSceneH * 0.50)
        addOverlayText("HIGH SCORE  \(hiScore)", size: 22, y: kSceneH * 0.42)
        let again = arcadeLabel(size: 24, align: .center)
        again.text = "PRESS SPACE  ·  TAP TO PLAY AGAIN"
        again.position = CGPoint(x: kSceneW / 2, y: kSceneH * 0.28)
        again.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        overlay.addChild(again)
    }

    private func gameOver() {
        mode = .gameOver
        hero.isHidden = true
        clearActors()
        clearOverlay()
        commitHiScore()
        addOverlayText("GAME OVER", size: 64, y: kSceneH * 0.62)
        addOverlayText("SCORE  \(score)", size: 30, y: kSceneH * 0.50)
        addOverlayText("HIGH SCORE  \(hiScore)", size: 22, y: kSceneH * 0.42)
        let again = arcadeLabel(size: 24, align: .center)
        again.text = "PRESS SPACE  ·  TAP TO RESTART"
        again.position = CGPoint(x: kSceneW / 2, y: kSceneH * 0.28)
        again.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        overlay.addChild(again)
    }

    private func commitHiScore() {
        if score > hiScore {
            hiScore = score
            UserDefaults.standard.set(hiScore, forKey: "ufo.hiscore")
        }
    }

    // MARK: Main loop

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat = lastUpdate > 0 ? CGFloat(min(currentTime - lastUpdate, 1.0 / 30.0)) : 1.0 / 60.0
        lastUpdate = currentTime

        pollController()
        scrollBackground(dt)

        switch mode {
        case .title, .gameOver:
            break
        case .ready:
            // hero gently bobs while the light counts down
            hero.position = CGPoint(x: heroPos.x, y: heroPos.y + sinApprox(CGFloat(currentTime) * 3) * 6)
        case .playing:
            stepPlaying(dt, time: CGFloat(currentTime))
        case .levelUp:
            break
        }
    }

    private func stepPlaying(_ dt: CGFloat, time: CGFloat) {
        moveHero(dt)
        handleFiring(dt)
        spawnLogic(dt)
        moveEnemies(dt, time: time)
        moveBullets(dt)
        moveItems(dt)
        moveDrifters(dt)
        collisions()
        if shieldTime > 0 {
            shieldTime -= dt
            hero.alpha = 0.55 + 0.45 * sinApprox(time * 12)
            if shieldTime <= 0 { hero.alpha = 1; updateHUD() }
        }
        // Level clear condition
        if killsThisLevel >= killsNeeded && enemies.isEmpty && !bossActive {
            completeLevel()
        }
    }

    // MARK: Hero movement

    private func moveHero(_ dt: CGFloat) {
        let accel: CGFloat = 2400
        let maxSpeed: CGFloat = 520
        let damp: CGFloat = 0.86

        var ax: CGFloat = 0, ay: CGFloat = 0
        if keyLeft  { ax -= 1 }
        if keyRight { ax += 1 }
        if keyUp    { ay += 1 }
        if keyDown  { ay -= 1 }

        if stickActive {
            let dx = stickCurrent.x - stickAnchor.x
            let dy = stickCurrent.y - stickAnchor.y
            let mag = sqrtApprox(dx * dx + dy * dy)
            if mag > 6 {
                let clamped = min(mag, 90) / 90
                ax = dx / mag * clamped
                ay = dy / mag * clamped
            }
        }

        if let pad {
            let stick = pad.leftThumbstick
            if absF(CGFloat(stick.xAxis.value)) > 0.12 { ax = CGFloat(stick.xAxis.value) }
            if absF(CGFloat(stick.yAxis.value)) > 0.12 { ay = CGFloat(stick.yAxis.value) }
        }

        heroVel.dx += ax * accel * dt
        heroVel.dy += ay * accel * dt

        if ax == 0 { heroVel.dx *= damp }
        if ay == 0 { heroVel.dy *= damp }

        heroVel.dx = clampF(heroVel.dx, -maxSpeed, maxSpeed)
        heroVel.dy = clampF(heroVel.dy, -maxSpeed, maxSpeed)

        heroPos.x += heroVel.dx * dt
        heroPos.y += heroVel.dy * dt
        heroPos.x = clampF(heroPos.x, 60, kSceneW - 60)
        heroPos.y = clampF(heroPos.y, 60, kSceneH - 60)
        hero.position = heroPos

        // Bank the ship with vertical velocity (rotateShip homage).
        let targetRot = clampF(heroVel.dy / 1600, -0.4, 0.4)
        hero.zRotation += (targetRot - hero.zRotation) * min(1, dt * 10)
    }

    // MARK: Firing

    private func handleFiring(_ dt: CGFloat) {
        fireTimer -= dt
        let firing = keyFire || touchFiring || (pad?.buttonA.isPressed ?? false) || (pad?.rightTrigger.isPressed ?? false)
        let cadence: CGFloat = rapidFire ? 0.10 : 0.22
        if firing && fireTimer <= 0 {
            fireBullet()
            fireTimer = cadence
        }
    }

    private func fireBullet() {
        let p = kPilots[pilotIndex]
        let speed: CGFloat = 900
        if doubleLaser {
            spawnBullet(at: CGPoint(x: heroPos.x + 30, y: heroPos.y + 14), vx: speed, vy: 0, glyph: p.beam)
            spawnBullet(at: CGPoint(x: heroPos.x + 30, y: heroPos.y - 14), vx: speed, vy: 0, glyph: p.beam)
            play("doublelaser.wav")
        } else {
            spawnBullet(at: CGPoint(x: heroPos.x + 30, y: heroPos.y), vx: speed, vy: 0, glyph: p.beam)
            play("fire.wav")
        }
    }

    private func spawnBullet(at pos: CGPoint, vx: CGFloat, vy: CGFloat, glyph: String) {
        let n = makeEmoji(glyph, size: 22)
        n.zPosition = Z.bullet
        n.position = pos
        world.addChild(n)
        bullets.append(Bullet(node: n, vx: vx, vy: vy, radius: 12))
    }

    private func moveBullets(_ dt: CGFloat) {
        for b in bullets {
            b.node.position.x += b.vx * dt
            b.node.position.y += b.vy * dt
        }
        bullets.removeAll { b in
            let x = b.node.position.x
            if x > kSceneW + 40 || x < -40 {
                b.node.removeFromParent(); return true
            }
            return false
        }

        for s in enemyShots {
            s.node.position.x += s.vx * dt
            s.node.position.y += s.vy * dt
        }
        enemyShots.removeAll { s in
            let x = s.node.position.x, y = s.node.position.y
            if x < -40 || x > kSceneW + 40 || y < -40 || y > kSceneH + 40 {
                s.node.removeFromParent(); return true
            }
            return false
        }
    }

    // MARK: Enemy spawning

    private func spawnLogic(_ dt: CGFloat) {
        // Boss every 4th level once the kill quota is met.
        if !bossActive && killsThisLevel >= killsNeeded && level % 4 == 0 {
            spawnBoss()
            return
        }
        if bossActive { return }
        if killsThisLevel >= killsNeeded { return }   // stop spawning; clear stragglers

        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnEnemy()
            let base = max(0.5, 1.6 - CGFloat(level) * 0.08)
            spawnTimer = CGFloat.random(in: base ... base + 0.7)
        }
    }

    private func spawnEnemy() {
        let w = kWorlds[worldIndex(forLevel: level)]
        let glyph = w.enemies.randomElement() ?? "🦖"
        let y = CGFloat.random(in: 120 ... kSceneH - 120)
        let n = makeEmoji(glyph, size: CGFloat.random(in: 46...58))
        n.zPosition = Z.enemy
        n.position = CGPoint(x: kSceneW + 50, y: y)
        world.addChild(n)
        let speed = -CGFloat.random(in: 120 ... 120 + CGFloat(level) * 14)
        let hp = 1 + level / 5
        let e = Enemy(node: n,
                      vx: speed, vy: 0, baseY: y,
                      phase: CGFloat.random(in: 0 ... 6.28),
                      wobble: CGFloat.random(in: 30...90),
                      hp: hp,
                      points: Int.random(in: 5...15) * 5,
                      radius: 30,
                      fireCooldown: CGFloat.random(in: 1.5...3.5),
                      isBoss: false)
        // 1-in-3 enemies dive toward the player
        e.diving = Int.random(in: 0..<3) == 0
        enemies.append(e)
    }

    private func spawnBoss() {
        bossActive = true
        let w = kWorlds[worldIndex(forLevel: level)]
        let glyph: String = w.enemies.last ?? "👹"
        let n = makeEmoji(glyph, size: 140)
        n.zPosition = Z.enemy
        n.position = CGPoint(x: kSceneW + 120, y: kSceneH / 2)
        world.addChild(n)
        let crown = makeEmoji("👑", size: 54)
        crown.position = CGPoint(x: 0, y: 80)
        n.addChild(crown)
        let boss = Enemy(node: n, vx: -90, vy: 120, baseY: kSceneH / 2,
                         phase: 0, wobble: kSceneH * 0.30,
                         hp: 40 + level * 4, points: 1000, radius: 70,
                         fireCooldown: 1.2, isBoss: true)
        enemies.append(boss)

        let banner = arcadeLabel(size: 40, align: .center)
        banner.text = "⚠️ BOSS ⚠️"
        banner.position = CGPoint(x: kSceneW / 2, y: kSceneH - 120)
        banner.run(.sequence([.wait(forDuration: 1.6), .fadeOut(withDuration: 0.5), .removeFromParent()]))
        overlay.addChild(banner)
    }

    private func moveEnemies(_ dt: CGFloat, time: CGFloat) {
        for e in enemies {
            if e.isBoss {
                // Boss eases to the right third and patrols vertically.
                let targetX = kSceneW - 180
                if e.node.position.x > targetX {
                    e.node.position.x += e.vx * dt
                } else {
                    e.node.position.x = targetX
                }
                e.node.position.y += e.vy * dt
                if e.node.position.y > kSceneH - 120 { e.vy = -absF(e.vy) }
                if e.node.position.y < 120 { e.vy = absF(e.vy) }
            } else {
                e.node.position.x += e.vx * dt
                if e.diving {
                    // steer toward the hero's y
                    let dy = heroPos.y - e.node.position.y
                    e.node.position.y += clampF(dy, -140, 140) * dt
                } else {
                    e.phase += dt * 2
                    e.node.position.y = e.baseY + sinApprox(e.phase) * e.wobble
                }
                e.node.position.y = clampF(e.node.position.y, 60, kSceneH - 60)
            }

            // Enemy fire
            e.fireCooldown -= dt
            if e.fireCooldown <= 0 && e.node.position.x < kSceneW - 40 && e.node.position.x > 80 {
                enemyFire(from: e)
                e.fireCooldown = e.isBoss ? CGFloat.random(in: 0.4...0.9) : CGFloat.random(in: 2.0...4.5)
            }
        }
        // Cull off-screen-left (non-boss only); they don't count as kills.
        enemies.removeAll { e in
            if !e.isBoss && e.node.position.x < -80 {
                e.node.removeFromParent(); return true
            }
            return false
        }
    }

    private func enemyFire(from e: Enemy) {
        let dx = heroPos.x - e.node.position.x
        let dy = heroPos.y - e.node.position.y
        let mag = max(1, sqrtApprox(dx * dx + dy * dy))
        let speed: CGFloat = e.isBoss ? 460 : 360
        let n = makeEmoji(e.isBoss ? "🔥" : "🟥", size: 22)
        n.zPosition = Z.bullet
        n.position = e.node.position
        world.addChild(n)
        enemyShots.append(Bullet(node: n, vx: dx / mag * speed, vy: dy / mag * speed, radius: 12))
        if e.isBoss { play("boom.wav") }
    }

    // MARK: Items / power-ups

    private func maybeDropItem(at pos: CGPoint, forceLife: Bool = false) {
        if forceLife {
            dropItem(.extraLife, at: pos); return
        }
        // ~14% drop rate
        guard Int.random(in: 0..<100) < 14 else { return }
        let kind = PowerKind.allCases.randomElement() ?? .bonus
        dropItem(kind, at: pos)
    }

    private func dropItem(_ kind: PowerKind, at pos: CGPoint) {
        let n = makeEmoji(kind.glyph, size: 40)
        n.zPosition = Z.item
        n.position = pos
        n.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.4), .scale(to: 1.0, duration: 0.4)])))
        world.addChild(n)
        items.append(Item(node: n, kind: kind, vx: -130, vy: 0, phase: CGFloat.random(in: 0...6.28)))
    }

    private func moveItems(_ dt: CGFloat) {
        for it in items {
            it.phase += dt * 3
            it.node.position.x += it.vx * dt
            it.node.position.y += sinApprox(it.phase) * 40 * dt
        }
        items.removeAll { it in
            if it.node.position.x < -60 { it.node.removeFromParent(); return true }
            return false
        }
    }

    private func applyPower(_ kind: PowerKind) {
        switch kind {
        case .doubleLaser:
            doubleLaser = true
        case .rapidFire:
            rapidFire = true
        case .shield:
            shieldTime = 8
        case .extraLife:
            lives = min(lives + 1, 9)
            play("extralife.wav")
        case .bonus:
            addScore(500)
        case .smartBomb:
            detonateSmartBomb()
        }
        if kind != .extraLife { play("powerup.wav") }
        updateHUD()
    }

    private func detonateSmartBomb() {
        // Clear every non-boss enemy + enemy shot on screen; chip the boss.
        for e in enemies {
            if e.isBoss {
                e.hp -= 12
                if e.hp <= 0 { explode(at: e.node.position, big: true); addScore(e.points); e.node.removeFromParent() }
            } else {
                explode(at: e.node.position, big: false)
                addScore(e.points)
                killsThisLevel += 1
                e.node.removeFromParent()
            }
        }
        enemies.removeAll { $0.isBoss ? $0.hp <= 0 : true }
        for s in enemyShots { s.node.removeFromParent() }
        enemyShots.removeAll()
        flashScreen(SKColor.white)
        play("explosion.wav")
    }

    // MARK: Friendly drifters (goodies)

    private func spawnDrifter() {
        let w = kWorlds[worldIndex(forLevel: level)]
        let glyph = w.goodies.randomElement() ?? "🦋"
        let y = CGFloat.random(in: 140 ... kSceneH - 140)
        let n = makeEmoji(glyph, size: 44)
        n.zPosition = Z.item
        n.position = CGPoint(x: kSceneW + 40, y: y)
        world.addChild(n)
        drifters.append(Drifter(node: n, vx: -CGFloat.random(in: 70...120), baseY: y, phase: CGFloat.random(in: 0...6.28)))
    }

    private func moveDrifters(_ dt: CGFloat) {
        drifterTimer -= dt
        if drifterTimer <= 0 {
            spawnDrifter()
            drifterTimer = CGFloat.random(in: 3.5...6.5)
        }
        for d in drifters {
            d.phase += dt * 1.5
            d.node.position.x += d.vx * dt
            d.node.position.y = d.baseY + sinApprox(d.phase) * 50
        }
        drifters.removeAll { d in
            if d.node.position.x < -60 { d.node.removeFromParent(); return true }
            return false
        }
    }

    // MARK: Collisions (AABB / radial)

    private func killEnemy(_ e: Enemy) {
        explode(at: e.node.position, big: e.isBoss)
        addScore(e.points)
        if e.isBoss {
            bossActive = false
            maybeDropItem(at: e.node.position, forceLife: true)   // guaranteed extra life
        } else {
            killsThisLevel += 1
            maybeDropItem(at: e.node.position)
        }
        e.node.removeFromParent()
    }

    private func collisions() {
        // hero bullets vs enemies (and friendly drifters for a bonus). A bullet
        // is consumed by the first thing it hits; survivors carry on.
        var survivingBullets: [Bullet] = []
        survivingBullets.reserveCapacity(bullets.count)
        for b in bullets {
            var consumed = false
            for e in enemies where e.hp > 0 {
                if hit(b.node.position, b.radius, e.node.position, e.radius) {
                    consumed = true
                    e.hp -= 1
                    e.node.run(.sequence([.scale(to: 1.3, duration: 0.05), .scale(to: 1.0, duration: 0.05)]))
                    if e.hp <= 0 { killEnemy(e) }
                    break
                }
            }
            if !consumed {
                for d in drifters where d.node.parent != nil {
                    if hit(b.node.position, b.radius, d.node.position, 26) {
                        consumed = true
                        explode(at: d.node.position, big: false)
                        addScore(250)
                        d.node.removeFromParent()
                        break
                    }
                }
            }
            if consumed { b.node.removeFromParent() } else { survivingBullets.append(b) }
        }
        bullets = survivingBullets
        enemies.removeAll { $0.hp <= 0 }
        drifters.removeAll { $0.node.parent == nil }

        guard !hero.isHidden else { return }

        // hero vs items (collect)
        items.removeAll { it in
            if hit(heroPos, heroRadius, it.node.position, 26) {
                applyPower(it.kind)
                it.node.removeFromParent()
                return true
            }
            return false
        }

        // hero vs drifters (collect bonus by flying through)
        drifters.removeAll { d in
            if hit(heroPos, heroRadius, d.node.position, 26) {
                addScore(150)
                let pop = makeEmoji("✨", size: 30)
                pop.position = d.node.position
                pop.zPosition = Z.fx
                world.addChild(pop)
                pop.run(.sequence([.group([.scale(to: 1.8, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
                d.node.removeFromParent()
                return true
            }
            return false
        }

        if shieldTime > 0 { return }   // invincible

        // enemy shots vs hero
        for (si, s) in enemyShots.enumerated() {
            if hit(heroPos, heroRadius * 0.7, s.node.position, s.radius) {
                s.node.removeFromParent()
                enemyShots.remove(at: si)
                heroHit()
                return
            }
        }
        // enemies vs hero
        for e in enemies {
            if hit(heroPos, heroRadius * 0.8, e.node.position, e.radius * 0.8) {
                if !e.isBoss {
                    explode(at: e.node.position, big: false)
                    e.node.removeFromParent()
                    enemies.removeAll { $0 === e }
                }
                heroHit()
                return
            }
        }
    }

    private func heroHit() {
        play("hit.wav")
        explode(at: heroPos, big: true)
        flashScreen(SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.5))
        lives -= 1
        doubleLaser = false
        rapidFire = false
        updateHUD()
        if lives <= 0 {
            gameOver()
        } else {
            // brief respawn invincibility
            shieldTime = 2.5
            heroPos = CGPoint(x: 220, y: kSceneH / 2)
            heroVel = .zero
            hero.position = heroPos
        }
    }

    // MARK: Scoring

    private func addScore(_ pts: Int) {
        score += pts
        if score >= nextExtraLifeAt {
            lives = min(lives + 1, 9)
            nextExtraLifeAt += 5000
            play("extralife.wav")
        }
        if score > hiScore { hiScore = score }
        updateHUD()
    }

    // MARK: FX

    private func explode(at pos: CGPoint, big: Bool) {
        play(big ? "explosion.wav" : "boom.wav")
        let burst = makeEmoji("💥", size: big ? 90 : 54)
        burst.position = pos
        burst.zPosition = Z.fx
        world.addChild(burst)
        burst.run(.sequence([
            .group([.scale(to: big ? 2.0 : 1.4, duration: 0.28), .fadeOut(withDuration: 0.28)]),
            .removeFromParent(),
        ]))
        // a few sparks
        for _ in 0..<(big ? 6 : 3) {
            let s = makeEmoji(["✨", "⭐️", "💫"].randomElement()!, size: CGFloat.random(in: 18...30))
            s.position = pos
            s.zPosition = Z.fx
            world.addChild(s)
            let dx = CGFloat.random(in: -70...70), dy = CGFloat.random(in: -70...70)
            s.run(.sequence([
                .group([.move(by: CGVector(dx: dx, dy: dy), duration: 0.4), .fadeOut(withDuration: 0.4)]),
                .removeFromParent(),
            ]))
        }
    }

    private func flashScreen(_ color: SKColor) {
        let flash = SKSpriteNode(color: color, size: CGSize(width: kSceneW, height: kSceneH))
        flash.anchorPoint = CGPoint(x: 0, y: 0)
        flash.position = .zero
        flash.zPosition = Z.overlay - 1
        hud.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: Cleanup helpers

    private func clearActors() {
        for e in enemies { e.node.removeFromParent() }
        for b in bullets { b.node.removeFromParent() }
        for s in enemyShots { s.node.removeFromParent() }
        for it in items { it.node.removeFromParent() }
        for d in drifters { d.node.removeFromParent() }
        enemies.removeAll(); bullets.removeAll(); enemyShots.removeAll()
        items.removeAll(); drifters.removeAll()
    }

    private func clearOverlay() {
        overlay.removeAllChildren()
    }

    // MARK: Input — keyboard (macOS virtual key codes, as delivered by the runtime)

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 0:  keyLeft = true              // ← / A
        case 124, 2:  keyRight = true             // → / D
        case 126, 13: keyUp = true                // ↑ / W
        case 125, 1:  keyDown = true              // ↓ / S
        case 49:                                  // space
            keyFire = true
            handleConfirm()
        case 18:  selectPilot(0)                  // 1
        case 19:  selectPilot(1)                  // 2
        case 20:  selectPilot(2)                  // 3
        default: break
        }
    }

    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 123, 0:  keyLeft = false
        case 124, 2:  keyRight = false
        case 126, 13: keyUp = false
        case 125, 1:  keyDown = false
        case 49:      keyFire = false
        default: break
        }
    }

    private func selectPilot(_ i: Int) {
        guard mode == .title, i >= 0, i < kPilots.count else { return }
        pilotIndex = i
        refreshPilotLine()
        updateHUD()
    }

    private func handleConfirm() {
        switch mode {
        case .title:    startNewGame()
        case .gameOver: showTitle()
        default: break
        }
    }

    // MARK: Input — touch / mouse (virtual flight yoke + fire)

    override func touchBegan(finger: Int, at p: CGPoint) { pointerDown(p) }
    override func touchMoved(finger: Int, at p: CGPoint) { pointerMove(p) }
    override func touchEnded(finger: Int, at p: CGPoint) { pointerUp(p) }

    override func mouseDown(with event: NSEvent) { pointerDown(event.location(in: self)) }
    override func mouseDragged(with event: NSEvent) { pointerMove(event.location(in: self)) }
    override func mouseUp(with event: NSEvent) { pointerUp(event.location(in: self)) }

    private func pointerDown(_ p: CGPoint) {
        switch mode {
        case .title:
            // Tapping the pilot line cycles pilots; anywhere else starts.
            if p.y > kSceneH * 0.42 && p.y < kSceneH * 0.54 {
                selectPilot((pilotIndex + 1) % kPilots.count)
            } else {
                startNewGame()
            }
        case .gameOver:
            showTitle()
        case .playing:
            stickActive = true
            stickAnchor = p
            stickCurrent = p
            touchFiring = true
        default:
            break
        }
    }

    private func pointerMove(_ p: CGPoint) {
        if mode == .playing && stickActive { stickCurrent = p }
    }

    private func pointerUp(_ p: CGPoint) {
        stickActive = false
        touchFiring = false
        heroVel.dx *= 0.4
        heroVel.dy *= 0.4
    }

    // MARK: Gamepad

    private func setupController() {
        GCController.startWirelessControllerDiscovery()
        pad = GCController.controllers().first?.extendedGamepad
    }

    private var prevPadA = false
    private func pollController() {
        // Acquire a controller lazily — the Web Gamepad API only surfaces a pad
        // after the first input, so re-poll until one appears (no notifications).
        if pad == nil { pad = GCController.controllers().first?.extendedGamepad }
        guard let pad else { return }
        let aDown = pad.buttonA.isPressed
        if aDown && !prevPadA && (mode == .title || mode == .gameOver) {
            handleConfirm()
        }
        prevPadA = aDown
    }

    // MARK: Audio

    private func play(_ file: String) {
        run(.playSoundFileNamed(file, waitForCompletion: false))
    }

    // MARK: Factory helpers

    private func makeEmoji(_ text: String, size: CGFloat, align: SKLabelHorizontalAlignmentMode = .center) -> SKLabelNode {
        let n = SKLabelNode(fontNamed: kEmojiFont)
        n.text = text
        n.fontSize = size
        n.horizontalAlignmentMode = align
        n.verticalAlignmentMode = .center
        return n
    }

    private func arcadeLabel(size: CGFloat, align: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let n = SKLabelNode(fontNamed: kArcadeFont)
        n.fontSize = size
        n.fontColor = .white
        n.horizontalAlignmentMode = align
        n.verticalAlignmentMode = .center
        return n
    }

    private func addOverlayText(_ text: String, size: CGFloat, y: CGFloat) {
        let n = arcadeLabel(size: size, align: .center)
        n.text = text
        n.position = CGPoint(x: kSceneW / 2, y: y)
        overlay.addChild(n)
    }
}

// MARK: - Small math helpers (avoid Foundation surprises in the wasm subset)

private func hit(_ a: CGPoint, _ ra: CGFloat, _ b: CGPoint, _ rb: CGFloat) -> Bool {
    let dx = a.x - b.x, dy = a.y - b.y
    let r = ra + rb
    return dx * dx + dy * dy <= r * r
}

private func clampF(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }
private func absF(_ v: CGFloat) -> CGFloat { v < 0 ? -v : v }

private func sqrtApprox(_ v: CGFloat) -> CGFloat { v <= 0 ? 0 : CGFloat(Double(v).squareRoot()) }

// SuperBox64Kit's SpriteKit module vends sin/cos/hypot (CGPath.swift); wrap sin
// so the call sites read cleanly and stay easy to swap if the subset changes.
private func sinApprox(_ x: CGFloat) -> CGFloat { sin(x) }

private func mix(_ a: SKColor, _ b: SKColor, _ t: CGFloat) -> SKColor {
    SKColor(red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t,
            alpha: 1)
}
