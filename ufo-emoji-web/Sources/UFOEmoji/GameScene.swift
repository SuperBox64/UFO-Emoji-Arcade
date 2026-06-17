 //
 //  GameScene.swift
 //  UFO Emoji
 //
 //  Created by Todd Bruss on 5/9/20, Updated Oct 15, 2024.
 //  Copyright (c) 2026 Todd Bruss. All rights reserved.
 //
 
 import SpriteKit
 import AVFoundation
 
 class GameScene: SKScene, FlightYokeProtocol, SKPhysicsContactDelegate, AVAudioPlayerDelegate {
    
    //MARK: Determine if demoMode is ON/OFF
    let demoMode = false
     
    //MARK: Flight Stick
    let zero = CGFloat(0.0), dampZero = CGFloat(0.0), dampMax = CGFloat(40.0)
    let ease = TimeInterval(0.08), shipduration = TimeInterval(0.005)
    let shipMax = CGFloat(500.0)
    let shipCtr = CGFloat(250.0)
    let shipMin = CGFloat(-500.0)
    
    //var alternator = false
    
    func FlightYokePilot(velocity: CGVector?, zRotation: CGFloat?) {
        //MARK: reference to hero's physic's body - easier
        guard
            let hero = hero,
            let pb = hero.physicsBody,
            let velocity = velocity,
            let zRotation = zRotation
        else { return }
        
        func rotateShip (_ t: TimeInterval, _ angle: CGFloat ) {
            let rot = SKAction.rotate(toAngle: angle, duration: t)
            rot.timingMode = .easeInEaseOut
            hero.run(rot)
        }
        
        if velocity == CGVector.zero {
            pb.linearDamping = dampMax
            pb.velocity = velocity
            
            rotateShip(ease, zRotation)
        } else {
            pb.linearDamping = CGFloat(dampZero)
            pb.velocity = velocity
            
            //MARK: Clamp using min max
            func clamp (_ f: CGFloat) -> CGFloat {
                min(max(f, shipMin), shipMax)
            }
            
            //MARK: Add a little extra to our ships movement
            pb.applyImpulse(CGVector( dx: velocity.dx / shipCtr, dy: velocity.dy / shipMax))
            
            //MARK: make sure we don't exceed 500 - Impulse is an accelerant
            pb.velocity.dx = clamp(pb.velocity.dx)
            pb.velocity.dy = clamp(pb.velocity.dy)
            
            rotateShip(shipduration, zRotation)
        }
    }
    
    private var QuadFireBombHUD : SKReferenceNode!
    private var AlienYokeDpdHUD : SKReferenceNode!
    private var parallax = SKReferenceNode()
    
    typealias Oreo = (bombsbutton:SKSpriteNode?,firebutton:SKSpriteNode?,hero:SKSpriteNode?,canape:SKSpriteNode?,tractor:SKSpriteNode?,bombsbutton2:SKSpriteNode?,firebutton2:SKSpriteNode?)
    
    private weak var firstBody : SKPhysicsBody!
    private weak var secondBody : SKPhysicsBody!
    private weak var bombsbutton: SKSpriteNode!
    private weak var firebutton: SKSpriteNode!
    private weak var bombsbutton2: SKSpriteNode!
    private weak var firebutton2: SKSpriteNode!
    private weak var hero:SKSpriteNode!
    private weak var canape:SKSpriteNode!
    private weak var tractor:SKSpriteNode!
    private weak var world: SKNode!
    private var FlightYoke : GTFlightYoke!
    
    private var heroEmoji:SKLabelNode!
    private var audioPlayer: AVAudioPlayer!
    private var cam : SKCameraNode!
    private var scoreLabelNode:SKLabelNode!
    private var highScoreLabelNode:SKLabelNode!
    private var readySetGoNode:SKLabelNode!
    private var highScoreLabel:SKLabelNode!
    private var livesLabel:SKLabelNode!
    private var livesLabelNode:SKLabelNode!
    
    private var screenHeight : CGFloat!
    private var score : Int!
    private lazy var level = Int()
    private var highscore : Int!
    private var lives : Int!
    private var highlevel : Int!
    private var rockBounds : CGRect!
    private lazy var scoreDict: [String:Int]! = [:]
    
    private var maxVelocity = CGFloat(0)
    private let heroCategory:UInt32       =  1
    private let worldCategory:UInt32      =  2
    private let bombBoundsCategory:UInt32 =  4
    private let badFishCategory:UInt32    =  8
    private let badGuyCategory:UInt32     =  16
    private let tractorCategory:UInt32    =  32
    private let laserbeam: UInt32         =  64
    private let wallCategory:UInt32       =  128
    private let itemCategory:UInt32       =  256
    private let fishCategory:UInt32       =  512
    private let charmsCategory:UInt32     =  1024
    private let levelupCategory:UInt32    =  2048
    private let laserBorder:UInt32        =  4096
    
    //Game Projectiles
    private var 🛥 : Bool! = true
    private var 🍕 : CGFloat! = CGFloat(1)
    private lazy var 👁: SKSpriteNode! = SKSpriteNode()
    private lazy var 💣: SKSpriteNode! = SKSpriteNode()
    private let 🦞 = SKPhysicsBody(circleOfRadius: 16)
    private let 🧨: SKLabelNode! = SKLabelNode(fontNamed:emojifontname)
    private var 💩 : String! = "💩"
    private var 🚨 : String! = "fire.m4a"
    private var 💥 : String! = "wah2.m4a"
    private var 🌞 : UInt32! = UInt32(32)
    private let 🍺 : CGFloat! = CGFloat(16)
    private let 🍎 : String! = emojifontname
    private let 🍌 : String! = "🍌"
    private let 🦸 : String! = "laserbeam"
    private let 🥾 : String! = "super"
    // Cached laser textures — resolved once per mode and reused every shot
    // instead of allocating a fresh SKTexture (and re-running the img_by_name
    // dict lookup) on each laserbeak. The GPU handle is already name-cached in
    // the runtime (imageByName returns the same handle per name); this only
    // saves the per-shot Swift SKTexture alloc, matching SKSpriteNode.copy()'s
    // texture-ref sharing.
    private var laserTex: SKTexture?
    private var superLaserTex: SKTexture?

    //we can swap these out if we use other emoji ships: 0 through 6
    
    deinit {
        parallax.removeAllChildren()
        parallax.removeFromParent()
        
        if let first = world.children.first, first.hasActions() {
            first.removeAllActions()
            first.removeAllChildren()
            first.removeFromParent()
        }
        
        if let w = world {
            w.removeAllActions()
            w.removeAllChildren()
            w.removeFromParent()
            w.parent?.removeAllChildren()
            w.parent?.removeFromParent()
        }
        
        if let c = cam {
            c.removeAllActions()
            c.removeAllChildren()
            c.removeFromParent()
            c.parent?.removeAllChildren()
            c.parent?.removeFromParent()
        }
        
        if let cm = camera {
            cm.removeAllActions()
            cm.removeAllChildren()
            cm.removeFromParent()
            cm.parent?.removeAllChildren()
            cm.parent?.removeFromParent()
        }
        
        if let scene = scene {
            scene.removeAllActions()
            scene.removeAllChildren()
            scene.removeFromParent()
            scene.parent?.removeAllChildren()
        }
        
        if hasActions() {
            removeAllActions()
        }
        
        if !children.isEmpty {
            removeAllChildren()
        }
        
        removeFromParent()
        
        audioPlayer = nil
        world = nil
        cam = nil
        QuadFireBombHUD = nil
        AlienYokeDpdHUD = nil
        firstBody = nil
        secondBody = nil
        bombsbutton = nil
        firebutton = nil
        bombsbutton2 = nil
        firebutton2 = nil
        hero = nil
        canape = nil
        tractor = nil
        FlightYoke = nil
        heroEmoji = nil
        audioPlayer = nil
        cam = nil
        scoreLabelNode = nil
        highScoreLabelNode = nil
        highScoreLabel = nil
        livesLabel = nil
        livesLabelNode = nil
        screenHeight = nil
        score = nil
        highscore = nil
        lives = nil
        highlevel = nil
        rockBounds = nil
        scoreDict = nil
    }
    
    func readyPlayerOne() -> Oreo? {
        var rocket = "aliensaucer"
        var glass = "aliencanape"
        var offset = 0
        var size = 24
        
        // alien
        if settings.emoji == 1 {
            rocket = "aliensaucer"
            glass = "aliencanape"
            offset = 10
            size = 26
        // monkey
        } else if settings.emoji == 2 {
            rocket = "monkeyrocket"
            glass = "monkeycanape"
            offset = 0
            size = 32
        // poop emoji
        }  else if settings.emoji == 3 {
            rocket = "poopship"
            glass = "poopcanape"
            offset = 0
            size = 36
        }
        
        func drawSpriteII(texture: String, name: String, category:UInt32, collision:UInt32, contact:UInt32, field:UInt32, dynamic:Bool, allowRotation:Bool, affectedGravity:Bool, zPosition:CGFloat, alpha:CGFloat, speed:CGFloat, alphaThreshold: Float) -> SKSpriteNode? {
            
            let sprite = SKSpriteNode(imageNamed: texture)
            
            sprite.texture?.preload { [ weak self ] in
                if name == "canape" {
                    let radius = sprite.size.width / 2 - 18
                    sprite.physicsBody = SKPhysicsBody(circleOfRadius: CGFloat(radius))
                    sprite.physicsBody?.restitution = 0
                    sprite.position = CGPoint(x:sprite.position.x, y: sprite.position.y + 30)
                } else if name == "hero" {
                    let radius = sprite.size.width / 4 - 6
                    sprite.physicsBody = SKPhysicsBody(circleOfRadius: CGFloat(radius))
                    sprite.physicsBody?.restitution = 0
                    sprite.position = CGPoint(x:sprite.position.x, y: sprite.position.y + 30)
                } else if name == "tractorbeam" {
                    let radius = sprite.size
                    sprite.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: radius.width + 5, height: radius.height + 5))
                    sprite.physicsBody?.restitution = 0
                    sprite.position = CGPoint(x:sprite.position.x, y: sprite.position.y - 25)
                }
                
                sprite.physicsBody?.categoryBitMask = category
                sprite.physicsBody?.collisionBitMask = collision
                sprite.physicsBody?.contactTestBitMask = contact
                sprite.physicsBody?.fieldBitMask = field
                sprite.physicsBody?.isDynamic = dynamic
                sprite.physicsBody?.allowsRotation = allowRotation
                sprite.physicsBody?.affectedByGravity = affectedGravity
                sprite.physicsBody?.velocity = CGVector.zero
                sprite.physicsBody?.applyImpulse(CGVector.zero)
                sprite.name = name
                sprite.zPosition = zPosition
                sprite.alpha = alpha
                sprite.speed = speed
                sprite.zRotation = 0.0
                sprite.isUserInteractionEnabled = false
                self?.addChild(sprite)
            }
            
            return sprite
        }
        
        func drawHudII( texture: String, name: String, category:UInt32, collision:UInt32, contact:UInt32, field:UInt32, dynamic:Bool, allowRotation:Bool, affectedGravity:Bool, zPosition:CGFloat, alpha:CGFloat, speed:CGFloat, alphaThreshold: Float) -> SKSpriteNode? {
            
            let sprite = SKSpriteNode(imageNamed: texture)
            let btnLoc = settings.stick ? "R" : "L"
            
            if name == "fire-right" || name == "hud-right" {
                sprite.position.x = sprite.size.width / 2
                sprite.position.y = -sprite.size.height / 2
            }
            
            if name == "fire-left" || name == "hud-left" {
                sprite.position.x = -sprite.size.width / 2
                sprite.position.y = sprite.size.height / 2
            }
            
            if name == "fire-top" || name == "hud-top" {
                sprite.position.x = sprite.size.width / 2
                sprite.position.y = sprite.size.height / 2
            }
            
            if name == "fire-down" || name == "hud-down" {
                sprite.position.x = -sprite.size.width / 2
                sprite.position.y = -sprite.size.height / 2
            }
            
            sprite.zPosition = 1000
            sprite.alpha = alpha
            sprite.name = name
            
            if name == "hud-right" || name == "hud-down" || name == "hud-top" || name == "hud-left" {
                sprite.isUserInteractionEnabled = true
            } else {
                sprite.isUserInteractionEnabled = false
            }
            
            QuadFireBombHUD.addChild(sprite)
            
            var xAdjust = CGFloat(1.0)
            var yAdjust = CGFloat(1.0)
            
            //iPhone (convert this to an enum)
            if settings.mode == 4 {
                xAdjust = CGFloat(1.4)
                yAdjust = CGFloat(1.1)
            }
            
            /* move the button to where we want them */
            if btnLoc == "L" {
                QuadFireBombHUD.position = CGPoint(
                    x: CGFloat(frame.size.width / -2 + (85 * xAdjust) ) ,
                    y: CGFloat(frame.size.height / -2 + (85 * yAdjust ) )
                )
            } else {
                QuadFireBombHUD.position = CGPoint(
                    x: CGFloat(frame.size.width / 2 - (85 * xAdjust)  ) ,
                    y: CGFloat(frame.size.height / -2 + (85 * yAdjust ) )
                )
            }
            
            if settings.mode == 1 {
                
                if btnLoc == "L" {
                    QuadFireBombHUD.position = CGPoint(x: CGFloat(frame.size.width / -2 + (87 * 0.75) ) ,y:  CGFloat(frame.size.height / -2 + (87 * 0.75)) )
                } else {
                    QuadFireBombHUD.position = CGPoint(x: CGFloat(frame.size.width / 2 - (87 * 0.75) ) ,y:  CGFloat(frame.size.height / -2 + (87 * 0.75)) )
                }
                
                QuadFireBombHUD.setScale(0.75)
            }
            
            return sprite
        }
        
        //drawsprites
        hero = drawSpriteII (
            texture: rocket,
            name: "hero",
            category: heroCategory,
            collision: wallCategory,
            contact: worldCategory + levelupCategory,
            field: 1,
            dynamic: true,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 150,
            alpha: 1.0,
            speed: 1,
            alphaThreshold: 1.0
        )
        
        heroEmoji = SKLabelNode(fontNamed:emojifontname) //"Apple Color Emoji"
        heroEmoji.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
        heroEmoji.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
        heroEmoji.alpha = 1.0
        heroEmoji.position = CGPoint(x: 0, y: offset)
        heroEmoji.fontSize = CGFloat(size)
        heroEmoji.zPosition = 24
        heroEmoji.text = heroArray[settings.emoji]
        hero.addChild(heroEmoji)
        
        if settings.emoji == 2 {
            self.emojiAnimation(emojis:["🙈","🙊","🙉","🐵"])
        }
        
        canape = drawSpriteII (
            texture: glass,
            name: "canape",
            category: heroCategory,
            collision: wallCategory,
            contact: worldCategory,
            field: 1,
            dynamic: true,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 160,
            alpha: 0.5,
            speed: 1,
            alphaThreshold: 0.0
        )
        
        tractor = drawSpriteII (
            texture: "tractorbeam",
            name: "tractorbeam",
            category: tractorCategory,
            collision: 0,
            contact: itemCategory + fishCategory,
            field: 1,
            dynamic: true,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 140,
            alpha: 0.1,
            speed: 1,
            alphaThreshold: 0.0
        )
        
        _ = drawHudII (
            texture: "hud45-right",
            name: "hud-right",
            category: 0,
            collision: 0,
            contact: 0,
            field: 0,
            dynamic: false,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 11,
            alpha: 1.0,
            speed: 0,
            alphaThreshold: 0
        )
        
        _ = drawHudII (
            texture: "hud45-left",
            name: "hud-left",
            category: 0,
            collision: 0,
            contact: 0,
            field: 0,
            dynamic: false,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 11,
            alpha: 1.0,
            speed: 0,
            alphaThreshold: 0
        )
        
        _ = drawHudII (
            texture: "hud45-btm",
            name: "hud-down",
            category: 0,
            collision: 0,
            contact: 0,
            field: 0,
            dynamic: false,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 11,
            alpha: 1.0,
            speed: 0,
            alphaThreshold: 0
        )
        
        _ = drawHudII (
            texture: "hud45-top",
            name: "hud-top",
            category: 0,
            collision: 0,
            contact: 0,
            field: 0,
            dynamic: false,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 11,
            alpha: 1.0,
            speed: 0,
            alphaThreshold: 0
        )
        
        firebutton = drawHudII (
            texture: "fire45-right",
            name: "fire-right",
            category: 0,
            collision: 0,
            contact: 0,
            field: 0,
            dynamic: false,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 10,
            alpha: 0.0001,
            speed: 0,
            alphaThreshold: 0
        )
        
        firebutton2 = drawHudII (
            texture: "fire45-left",
            name: "fire-left",
            category: 0,
            collision: 0,
            contact: 0,
            field: 0,
            dynamic: false,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 10,
            alpha: 0.0001,
            speed: 0,
            alphaThreshold: 0
        )
        
        bombsbutton2 = drawHudII (
            texture: "fire45-top",
            name: "fire-top",
            category: 0,
            collision: 0,
            contact: 0,
            field: 0,
            dynamic: false,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 10,
            alpha: 0.0001,
            speed: 0,
            alphaThreshold: 0
        )
        
        bombsbutton = drawHudII (
            texture: "fire45-btm",
            name: "fire-down",
            category: 0,
            collision: 0,
            contact: 0,
            field: 0,
            dynamic: false,
            allowRotation: false,
            affectedGravity: false,
            zPosition: 10,
            alpha: 0.0001,
            speed: 0,
            alphaThreshold: 0
        )
        
        func createHeroJoint() {
            guard
                let bodyA = hero.physicsBody,
                let bodyB = tractor.physicsBody,
                let anchor = hero.position as CGPoint?
            else { return }
            bodyA.density = 1.0
            let joint = SKPhysicsJointPin.joint(withBodyA: bodyA, bodyB: bodyB, anchor: anchor)
            physicsWorld.add(joint)
        }
        
        func createCanapeJoint() {
            guard
                let bodyA = hero.physicsBody,
                let bodyB = canape.physicsBody,
                let anchor = hero.position as CGPoint?
            else { return }
            
            let joint = SKPhysicsJointPin.joint(withBodyA: bodyA, bodyB: bodyB, anchor: anchor)
            joint.rotationSpeed = 1.0
            physicsWorld.add(joint)
        }
        
        func gtFlightYoke() {
            let stick = settings.stick ? "L" : "R"
            
            var xAdjust = CGFloat(1.0)
            var yAdjust = CGFloat(1.0)
            //iPhone (convert this to an enum)
            if settings.mode == 4 {
                xAdjust = CGFloat(1.4)
                yAdjust = CGFloat(1.1)
            }
            
            /* move the stick to where we want it */
            if stick == "L" {
                FlightYoke.position = CGPoint(
                    x: CGFloat(frame.size.width / -2 + (85 * xAdjust) ) ,
                    y: CGFloat(frame.size.height / -2 + (85 * yAdjust ) )
                )
            } else {
                FlightYoke.position = CGPoint(
                    x: CGFloat(frame.size.width / 2 - (85 * xAdjust)  ) ,
                    y: CGFloat(frame.size.height / -2 + (85 * yAdjust ) )
                )
            }
            
            FlightYoke.delegate = self
            AlienYokeDpdHUD.addChild(FlightYoke)
            
            FlightYoke.zPosition = 1000
            FlightYoke.name = "ArcadeJoyPad"
            
            if settings.mode == 1 {
                FlightYoke.setScale(0.75)
                
                let offset: CGFloat = 65.25
                let yPosition = frame.size.height / -2 + offset
                let xPosition = stick == "L" ? frame.size.width / -2 + offset : frame.size.width / 2 - offset
                
                FlightYoke.position = CGPoint(x: xPosition, y: yPosition)
            }
        }

        createCanapeJoint()
        createHeroJoint()
        gtFlightYoke()
        
        return (bombsbutton,firebutton,hero,canape,tractor,bombsbutton2,firebutton2)
    }
    
    // MARK: Keyboard controls (by joystick side; also drives the on-screen HUD)
    // settings.stick == true  => joystick on the LEFT  -> WASD = move, arrows = fire
    // settings.stick == false => joystick on the RIGHT -> arrows = move, WASD = fire
    // When the keyboard moves/fires, the on-screen yoke thumb (via stickMoved) and the
    // fire buttons (via firebomb) animate too — the "remote control". Gamepad d-pad/stick
    // already synthesize the same arrow keys, so this path covers keyboard AND gamepad.
    // skKeyIsDown/SKKey come from SuperBox64Kit on BOTH wasm builds (web wasip1 AND
    // Embedded); the native Apple app gets a no-op shim (see AppDelegate.swift), so this
    // is ONE unconditional path on every target. (It used to be gated on
    // hasFeature(Embedded), which silently dropped keyboard from the web/wasip1 build.)
    private var kbDriving = false
    private var kbPrevFireUp = false, kbPrevFireDown = false, kbPrevFireLeft = false, kbPrevFireRight = false

    private func pollKeyboardInput() {
        let joystickLeft = settings.stick
        let mUp: Bool; let mDown: Bool; let mLeft: Bool; let mRight: Bool
        let fUp: Bool; let fDown: Bool; let fLeft: Bool; let fRight: Bool
        if joystickLeft {   // WASD moves, arrows fire
            mUp = skKeyIsDown(SKKey.w);  mDown = skKeyIsDown(SKKey.s);    mLeft = skKeyIsDown(SKKey.a);    mRight = skKeyIsDown(SKKey.d)
            fUp = skKeyIsDown(SKKey.up); fDown = skKeyIsDown(SKKey.down); fLeft = skKeyIsDown(SKKey.left); fRight = skKeyIsDown(SKKey.right)
        } else {            // arrows move, WASD fires
            mUp = skKeyIsDown(SKKey.up); mDown = skKeyIsDown(SKKey.down); mLeft = skKeyIsDown(SKKey.left); mRight = skKeyIsDown(SKKey.right)
            fUp = skKeyIsDown(SKKey.w);  fDown = skKeyIsDown(SKKey.s);    fLeft = skKeyIsDown(SKKey.a);    fRight = skKeyIsDown(SKKey.d)
        }

        // Movement -> drive the flight yoke (stickMoved sets velocity AND moves the thumb).
        if mUp || mDown || mLeft || mRight {
            let reach: CGFloat = 1000   // stickMoved clamps to the thumb radius -> full deflection
            let x: CGFloat = (mRight ? reach : 0) + (mLeft ? -reach : 0)
            let y: CGFloat = (mUp ? reach : 0) + (mDown ? -reach : 0)
            FlightYoke?.stickMoved(location: CGPoint(x: x, y: y))
            kbDriving = true
        } else if kbDriving {
            FlightYoke?.stickMoved(location: .zero)   // released -> recenter once (don't fight touch input)
            kbDriving = false
        }

        // Fire -> 4-way, edge-triggered so one key press = one shot (matches a button tap).
        if let hero = hero,
           let heroVelocity = hero.physicsBody?.velocity,
           let heroRotation = hero.zRotation as CGFloat?,
           let heroPosition = hero.position as CGPoint?,
           let firebutton = self.firebutton, let firebutton2 = self.firebutton2,
           let bombsbutton = self.bombsbutton, let bombsbutton2 = self.bombsbutton2 {
            let superhero = (heroPosition, heroRotation, heroVelocity)
            if fRight && !kbPrevFireRight { laserbeak(superhero: superhero, reverse: false); firebomb(firebomb: firebutton) }
            if fLeft  && !kbPrevFireLeft  { laserbeak(superhero: superhero, reverse: true);  firebomb(firebomb: firebutton2) }
            if fDown  && !kbPrevFireDown  { bombaway(superhero: superhero, reverse: false);  firebomb(firebomb: bombsbutton) }
            if fUp    && !kbPrevFireUp    { bombaway(superhero: superhero, reverse: true);   firebomb(firebomb: bombsbutton2) }
        }
        kbPrevFireUp = fUp; kbPrevFireDown = fDown; kbPrevFireLeft = fLeft; kbPrevFireRight = fRight
    }

    //MARK: Function Update
    override func update(_ currentTime: TimeInterval) {

        // Drive the flight yoke from the kit's single per-frame call. The yoke
        // no longer owns a private CADisplayLink: the kit ticks scene.update(_:)
        // ONLY for the currently presented scene, so input sampling stops the
        // instant presentScene swaps to GameOver/LevelUp — no orphaned timer
        // ticking into a torn-down scene (the "Out of bounds call_indirect").
        FlightYoke?.update()
        pollKeyboardInput()

        guard
            let hero = hero,
            let pos = hero.position as CGPoint?
        else { return }
        
        if self.demoMode {
            let triggerScreenShot = Int.random(in: 1...1000)
            
            if triggerScreenShot == 500, let screenshot = view {
                UIGraphicsBeginImageContextWithOptions(screenshot.bounds.size, true, 0)
                screenshot.drawHierarchy(in: screenshot.bounds, afterScreenUpdates: true)
                if let image = UIGraphicsGetImageFromCurrentImageContext() {
                    UIGraphicsEndImageContext()
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            }
        }
       
        if pos.y > screenHeight && highScoreLabelNode.alpha > 0.0 {
            
            highScoreLabelNode.run(SKAction.fadeAlpha(to: 0.0, duration: 0.25))
            highScoreLabel.run(SKAction.fadeAlpha(to: 0.0, duration: 0.25))
            
        } else if (highScoreLabelNode.alpha < 0.4) {
            
            highScoreLabelNode.run(SKAction.fadeAlpha(to: 0.4, duration: 0.25))
            highScoreLabel.run(SKAction.fadeAlpha(to: 0.4, duration: 0.25))
        }
        
        /**
         used by meteorites and chopper
         */
        func movingObjectI() {
            world.children.first?.enumerateChildNodes(withName: "🤯") { node, _ in
                guard let body = node.physicsBody else { return }
                
                if body.isDynamic {
                    node.name = "💰"
                    let move = SKAction.moveTo(y: self.position.y, duration: 2.0)
                    node.run(move)
                }
            }
        }
        
        movingObjectI()
    }
    
    // The kit calls willMove(from:) on the OUTGOING scene inside presentScene
    // BEFORE swapping (SuperBox64Kit SKView.presentScene). Detach the yoke here
    // so it can never pilot a torn-down scene even if a transition path other
    // than removeGUI() fires. Belt-and-suspenders with update()'s optional-chain
    // and the removal of the yoke's private CADisplayLink.
    override func willMove(from view: SKView) {
        FlightYoke?.shutdown()
        super.willMove(from: view)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        FlightYoke = GTFlightYoke()
        FlightYoke.startup()
        world = childNode(withName: "world")
        
        // This is the default of King, Queen Nationality
        KingQueenGlobalDie = 100
        
        🔱 = false
        💠 = false
        🛡 = false
        🕹 = false
        doublelaser = 0
        
        if (settings.level >= 1 && settings.level <= maxlevel) {
            if let soundURL: URL = Bundle.main.url(forResource: "music1", withExtension: "mp3") {
                audioPlayer = try? AVAudioPlayer(contentsOf: soundURL)
            }
        }
        
        if settings.music {
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.stop()
            audioPlayer?.volume = 0.0
        }
        
        cam = SKCameraNode()
        camera = cam
        addChild(cam)
        cam.zPosition = 100
        
        AlienYokeDpdHUD = SKReferenceNode()
        QuadFireBombHUD = SKReferenceNode()
        
        AlienYokeDpdHUD.name = "AlienYokeDpdHUD"
        QuadFireBombHUD.name = "QuadFireBombHUD"
        cam.addChild(AlienYokeDpdHUD)
        cam.addChild(QuadFireBombHUD)
        
        QuadFireBombHUD.zRotation = CGFloat(Double.pi/4)
        
        //😸
        doublelaser = 0
        scoreDict[""] = 1
        scoreDict["🐽"] = 5
        scoreDict["🌸"] = 10
        scoreDict["🥛"] = 15
        scoreDict["🎁"] = 20
        scoreDict["🤠"] = 25
        scoreDict["🔥"] = 30
        scoreDict["🐝"] = 35
        scoreDict["🚔"] = 40
        scoreDict["🏢"] = 45
        scoreDict["👤"] = 50
        scoreDict["🖲"] = 55
        scoreDict["😰"] = 60 //super villians
        scoreDict["😨"] = 70 //super villians
        scoreDict["⭕️"] = 75 //heroes
        scoreDict["⁉️"] = 80 //heroes not flipped
        scoreDict["❌"] = 85 //villians
        scoreDict["‼️"] = 90 //Hero Villians not flipped
        scoreDict["😡"] = 100 //super villians
        scoreDict["😸"] = 105
        scoreDict["🤬"] = 110 //super villians
        scoreDict["😳"] = 120 //super villians
        scoreDict["😱"] = 130 //super villians
        scoreDict["🤯"] = 140 // Meteor or super villian
        scoreDict["😠"] = 150 // Meteor or super villian
        scoreDict["💰"] = 105 //rare
        scoreDict["💎"] = 110 //rare
        scoreDict["👑"] = 115 //rare
        scoreDict["❣️"] = 120 //extra life (displays him/herself in the game)
        scoreDict["🔫"] = 130 //super rare marker for double laser beams
        scoreDict["🔱"] = 140 //super rare trident (super bomb)
        scoreDict["🛡"] = 150 //super rare shields (cloaked ghost, move through walls)
        scoreDict["💠"] = 160 //super rare shields (cloaked ghost, move through walls)
        scoreDict["🕹"] = 170 //super rare shields (cloaked ghost, move through walls)
        scoreDict["land"] 	= 1
        scoreDict["dirt"] 	= 1
        scoreDict["grass"] 	= 2
        scoreDict["desert"] = 4
        scoreDict["sand"] 	= 4
        scoreDict["stone"] 	= 8
        scoreDict["gold"]   = 16
        scoreDict["straw"]  = 16
        
        (level, highlevel, score, highscore, lives) = loadScores()
        
        var background = ""
        
        switch level {
        
        //skyMtns
        case 1...5:
            background = "waterWorld" //waterWorld
        case 6...10:
            background = "miniDesert"
        case 11...15:
            background = "skyMtns"
        default :
            ()
        }
        
        settings.rapidfire = demoMode

        world.isPaused = true
        world.isHidden = true
        
        let gameWorld = GameWorld(world: world)
        
        world = gameWorld.gameLevel(filename: "level\(level)")
        world.isPaused = false
        world.isHidden = false
        
        for node in self.children {
            if (node.name == "world") {
                
                //Texture Map Node Stuff goes here
                for node in node.children {
                    
                    if node.name == "Rocky" {
                        let gameBoundsNode = SKNode()
                        
                        gameBoundsNode.zPosition = 50
                        rockBounds = node.frame
                        
                        physicsWorld.gravity = CGVector(dx: 0.0, dy: -3)
                        physicsWorld.contactDelegate = self
                        gameBoundsNode.physicsBody = SKPhysicsBody(edgeLoopFrom: rockBounds)
                        
                        gameBoundsNode.physicsBody?.categoryBitMask = wallCategory //2 + 8 + 128 + 256 + 512 + 1024
                        gameBoundsNode.physicsBody?.collisionBitMask = 0
                        gameBoundsNode.physicsBody?.restitution = 0.2
                        gameBoundsNode.physicsBody?.contactTestBitMask = 0
                        
                        addChild(gameBoundsNode)
                                                
                        var bounds = CGRect.zero
                        let extend = CGFloat(128)
                        let half = CGFloat(2)
                        let halfextend = extend / half
                        //MARK: Bounds now can only go so far off screen
                   
                        let w = self.size.width
                        let h = self.size.height
                        bounds = CGRect(x: -w / half - halfextend, y: -h / half, width: w + extend, height: h + extend)
                        
                        let addnode = SKNode()
                        addnode.name = "bombBounds"
                        addnode.zPosition = -10000
                        
                        addnode.physicsBody = SKPhysicsBody(edgeLoopFrom: bounds)
                        addnode.physicsBody?.categoryBitMask = bombBoundsCategory
                        self.camera?.addChild(addnode)
                        
                        //update positioning
                        let laserBoundsNode = SKNode()
                        
                        bounds = CGRect(x: -w / half, y: -h / half, width: w, height: h + extend)

                        laserBoundsNode.physicsBody = SKPhysicsBody(edgeLoopFrom: bounds )
                        laserBoundsNode.name = "🔲"
                        laserBoundsNode.physicsBody?.categoryBitMask = laserBorder
                        laserBoundsNode.physicsBody?.collisionBitMask = 0
                        laserBoundsNode.physicsBody?.contactTestBitMask = laserbeam
                        laserBoundsNode.physicsBody?.isDynamic = false
                        laserBoundsNode.physicsBody?.isResting = true
                        laserBoundsNode.isUserInteractionEnabled = false
                        laserBoundsNode.physicsBody?.affectedByGravity = false
                        laserBoundsNode.physicsBody?.restitution = 0
                        laserBoundsNode.speed = -1000
                        self.camera?.addChild(laserBoundsNode)
                        
                        node.removeFromParent()
                    }
                }
            }
        }
        
        let gameParallax = GameParallax(parallax: parallax, bounds: rockBounds)
        parallax = gameParallax.setParallax(texture: SKTexture(imageNamed: background))
        world.addChild(parallax)
        world?.speed = 1
        
        guard
            let sh = scene?.frame.size.height,
            let sw = scene?.frame.size.width
        else { return }
        
        let sceneheight = sh / 2
        let scenewidth = sw / 2

        screenHeight = sceneheight - 64
        
        let indent = scenewidth - 7.5 * CGFloat(settings.mode)
        let difference = CGFloat(20)
        let labelheight = sceneheight - difference
        let scoreheight = sceneheight - (difference * CGFloat(2))
        let scoreLabel = SKLabelNode(fontNamed:"Emulogic")
        scoreLabel.position = CGPoint( x: -indent, y: labelheight )
        scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        scoreLabel.alpha = 0.4
        scoreLabel.zPosition = 100
        scoreLabel.text = String("🎲")
        scoreLabel.fontSize = 14
        cam.addChild(scoreLabel)
        
        scoreLabelNode = SKLabelNode(fontNamed:"Emulogic")
        scoreLabelNode.position = CGPoint( x: -indent, y: scoreheight  )
        scoreLabelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        scoreLabelNode.alpha = 0.4
        scoreLabelNode.zPosition = 100
        scoreLabelNode.text = String(score)
        scoreLabelNode.fontSize = 14
        cam.addChild(scoreLabelNode)
        
        /* High Score */
        highScoreLabel = SKLabelNode(fontNamed:"Emulogic")
        highScoreLabel.position = CGPoint( x: 0, y: labelheight )
        highScoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
        highScoreLabel.alpha = 0.4
        highScoreLabel.zPosition = 100
        highScoreLabel.text = String("💎")
        highScoreLabel.fontSize = 14
        highScoreLabel.name = "highScoreLabel"
        cam.addChild(highScoreLabel)
        
        highScoreLabelNode = SKLabelNode(fontNamed:"Emulogic")
        highScoreLabelNode.position = CGPoint( x: 0, y: scoreheight )
        highScoreLabelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
        highScoreLabelNode.alpha = 0.4
        highScoreLabelNode.zPosition = 100
        highScoreLabelNode.text = String(highscore)
        highScoreLabelNode.fontSize = 14
        highScoreLabelNode.name = "highScoreLabelNode"
        cam.addChild(highScoreLabelNode)
        
        readySetGoNode = SKLabelNode(fontNamed:emojifontname)
        readySetGoNode.position = CGPoint( x: 0, y: 0 )
        readySetGoNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
        readySetGoNode.alpha = 1.0
        readySetGoNode.zPosition = 100
        readySetGoNode.text = String("🚥")
        readySetGoNode.fontSize = 72
        readySetGoNode.name = "highScoreLabelNode"
        cam.addChild(readySetGoNode)

        livesLabel = SKLabelNode(fontNamed:"Emulogic")
        livesLabel.position = CGPoint( x: indent, y: labelheight )
        livesLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.right
        livesLabel.alpha = 0.4
        livesLabel.zPosition = 100
        livesLabel.text = String("💛")
        livesLabel.fontSize = 14
        cam.addChild(livesLabel)
        
        livesLabelNode = SKLabelNode(fontNamed:"Emulogic")
        livesLabelNode.position = CGPoint( x: indent, y: scoreheight )
        livesLabelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.right
        livesLabelNode.alpha = 0.4
        livesLabelNode.zPosition = 100
        
        if lives > maxlives {
            lives = maxlives
        }
        
        if settings.emoji > 3 {
            settings.emoji = 3
        } else if settings.emoji < 1 {
            settings.emoji = 1
        }
                
        livesLabelNode.text = String(repeating: heroArray[settings.emoji], count: lives)
        livesLabelNode.fontSize = 14
        cam.addChild(livesLabelNode)
        
        if settings.music {
            self.audioPlayer?.numberOfLoops = -1
            self.audioPlayer?.play()
            self.audioPlayer?.volume = 1.0
        } else {
            self.audioPlayer?.numberOfLoops = 0
            self.audioPlayer?.stop()
            self.audioPlayer?.volume = 0.0
        }
        
        if settings.rapidfire {
            
            let autofire = SKAction.sequence(
                [ SKAction.run { [self] in
                              
                    switch UIApplication.shared.applicationState {
                    case .background, .inactive:
                        ()
                    case .active:

                        guard
                            let hero = hero,
                            let heroVelocity = hero.physicsBody?.velocity,
                            let heroRotation = hero.zRotation as CGFloat?,
                            let heroPosition = hero.position as CGPoint?
                        else
                        { return }
                        
                        func fireaway() {
                            let fire = Int.random(in: 1...8)
                            switch fire {
                            
                            case 1,2,3,4:
                                
                                if heroVelocity.dx > 0 {
                                    laserbeak(superhero: (heroPosition, heroRotation, heroVelocity), reverse: false)
                                } else if  heroVelocity.dx < 0 {
                                    laserbeak(superhero: (heroPosition, heroRotation, heroVelocity), reverse: true)
                                }
                                
                            case 5,6:
                                
                                if heroVelocity.dy < 0  {
                                    bombaway(superhero: (heroPosition, heroRotation, heroVelocity), reverse: false)
                                } else if heroVelocity.dy > 0 {
                                    bombaway(superhero: (heroPosition, heroRotation, heroVelocity), reverse: true)
                                }
                                
                            default:
                                ()
                            }
                        }
                        
                        func autoFire() {
                            if !🕹 {
                                fireaway()
                            }
                        }
                        
                        autoFire()
                    default:
                        break
                    }
                },
                
                SKAction.wait(forDuration: 0.1)
                
                ]
            )
            self.run( SKAction.repeatForever(autofire) )
        }
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let waitA = SKAction.wait(forDuration: 1.0)
        let waitB = SKAction.wait(forDuration: 1.3)

        readySetGoNode.run(SKAction.sequence([waitA,fadeOut]))
    
        let actionJackson = SKAction.run { [self] in
            guard let gamestartup = readyPlayerOne() else { return }
            
            hero = gamestartup.hero
            canape = gamestartup.canape
            tractor = gamestartup.tractor
            tractor.addGlow()
            bombsbutton = gamestartup.bombsbutton
            firebutton = gamestartup.firebutton
            bombsbutton2 = gamestartup.bombsbutton2
            firebutton2 = gamestartup.firebutton2
            
        }
        
        let sequence = SKAction.sequence([waitB,fadeIn,actionJackson]);
        self.run( sequence )
    }
    
    override func didSimulatePhysics() {
        
        guard
            let h = hero,
            let c = canape
        else
        { return }
        
        //camera node x position = hero's
        cam.position.x = h.position.x
        
        //canape and hero have the same rotation
        c.zRotation = h.zRotation
        
        // adds depth to the scene
        // by moving the backgorund slower
        parallax.position.x = cam.position.x * 0.334
    }
    
    
    public func emojiAnimation(emojis:Array<String>) {
        guard
            let hero = hero
        else { return }
        
        guard
            let emojiNode = hero.children.first as? SKLabelNode
        else { return }

        let wait = SKAction.wait(forDuration: 1.0)
        let sizeA = SKAction.run {
            emojiNode.fontSize = 34
            emojiNode.position.y = -1
        }
        
        let sizeB = SKAction.run {
            emojiNode.fontSize = 32
            emojiNode.position.y = 0
        }
    
        var animationSeqArr = [SKAction]()
        
        for x in 0..<emojis.count {
            let emoji = SKAction.run() { [weak emojiNode] in emojiNode?.text = emojis[x] }
            
            animationSeqArr.append(wait)
            if x < emojis.count - 1 {
                animationSeqArr.append(sizeA)
            } else {
                animationSeqArr.append(sizeB)
            }
            animationSeqArr.append(emoji)
        }
        
        hero.run(SKAction.repeatForever( SKAction.sequence( animationSeqArr ) ))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard
            let hero = self.hero,
            let heroVelocity = hero.physicsBody?.velocity,
            let heroRotation = hero.zRotation as CGFloat?,
            let heroPosition = hero.position as CGPoint?,
            let firebutton = self.firebutton,
            let firebutton2 = self.firebutton2,
            let bombsbutton = self.bombsbutton,
            let bombsbutton2 = self.bombsbutton2
        else { return }
        
        super.touchesBegan(touches as Set<UITouch>, with: event)
        
        for touch in touches {
            let location: CGPoint = touch.location(in: self)
            let touchedNode = atPoint(location)
            
            if let name = touchedNode.name {
                
                if name == "fire-right" || 🕹 {
                    laserbeak(superhero: (heroPosition, heroRotation, heroVelocity), reverse: false)
                    firebomb(firebomb: firebutton)
                }
                
                if name == "fire-left"  || 🕹 {
                    laserbeak(superhero: (heroPosition, heroRotation, heroVelocity), reverse: true)
                    firebomb(firebomb: firebutton2)
                }
                
                if name == "fire-down"  || 🕹 {
                    bombaway(superhero: (heroPosition, heroRotation, heroVelocity), reverse: false)
                    firebomb(firebomb: bombsbutton)
                }
                
                if name == "fire-top"  || 🕹 {
                    bombaway(superhero: (heroPosition, heroRotation, heroVelocity), reverse: true)
                    firebomb(firebomb: bombsbutton2)
                }
            }
        }
    }
    
    //To Do: Move this to GameHits
    func tractorBeamedThisItem(prize:SKSpriteNode?) {
        
        guard
            let prize = prize,
            let body = prize.physicsBody,
            prize.name != "🌠"
        else { return }
        
        // send the collisions to neverLand
        // this way the score cannot be counted twice or more
        // any prize or coin can get sucked up
        body.contactTestBitMask = 0
        body.categoryBitMask = 0 // will disable contact
        body.collisionBitMask = 0
        body.isResting = true
        body.isDynamic = false
        body.mass = 1
        prize.speed = 0.5
        
        let move = SKAction.moveBy(x: 0, y: 48, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: TimeInterval(0.2))
        let scale = SKAction.scale(to: 0.25, duration:TimeInterval(0.2))
        
        let extraPoints = tallyPoints(name: prize.name!)
        updateScore(extraPoints:extraPoints * 2)
        prize.name = "🌠"; // will disable contact
        let removeFromParent = SKAction.removeFromParent()
        prize.physicsBody?.isDynamic = false
        prize.run(SKAction.sequence([move]))
        prize.run(SKAction.sequence([fade]))
        prize.run(SKAction.sequence([scale,removeFromParent]))
    }
    
    func blueZ (pos: CGPoint) {
        if let smoke = SKEmitterNode(fileNamed: "blueParticle") {
            let fadeToZero = SKAction.fadeAlpha(to: 0.0, duration:TimeInterval(2.0))
            let removeFromParent = SKAction.removeFromParent()
            let destroyVaporDelay = SKAction.wait(forDuration: 2.0)
            smoke.run(SKAction.sequence([destroyVaporDelay,fadeToZero,removeFromParent]))
            smoke.position = pos
            smoke.alpha = 0.5
            smoke.speed = 5
            smoke.zPosition = 150
            addChild(smoke)
        }
        
        if settings.sound {
            let explosion: SKAction = SKAction.playSoundFileNamed("murrmurr.m4a", waitForCompletion: false)
            run(explosion)
        }
    }
    
    func smokeM (pos: CGPoint) {
        
        if let smoke = SKEmitterNode(fileNamed: "smokeParticle") {
            let fadeToZero = SKAction.fadeAlpha(to: 0.0, duration:TimeInterval(2.0))
            let removeFromParent = SKAction.removeFromParent()
            let destroyVaporDelay = SKAction.wait(forDuration: 2.0)
            smoke.run(SKAction.sequence([destroyVaporDelay,fadeToZero,removeFromParent]))
            smoke.position = pos
            smoke.speed = 5
            smoke.zPosition = 150
            addChild(smoke)
        }
        
        if settings.sound {
            let explosion: SKAction = SKAction.playSoundFileNamed("boomFire2.m4a", waitForCompletion: false)
            run(explosion)
        }
    }
    
    func magicParticle (pos: CGPoint) {
        guard let smoke = SKEmitterNode(fileNamed: "magicParticle") else { return }
        
        let fadeToZero = SKAction.fadeAlpha(to: 0.0, duration:TimeInterval(2.0))
        let removeFromParent = SKAction.removeFromParent()
        let destroyVaporDelay = SKAction.wait(forDuration: 2.0)
        smoke.run(SKAction.sequence([destroyVaporDelay,fadeToZero,removeFromParent]))
        smoke.position = pos
        smoke.speed = 5
        smoke.zPosition = 150
        addChild(smoke)
        
        if settings.sound {
            let explosion: SKAction = SKAction.playSoundFileNamed("boomFire2.m4a", waitForCompletion: false)
            run(explosion)
        }
    }
    
    
    func stoneVersusLaser(secondBody: SKPhysicsBody?, contactPoint: CGPoint? ) {
        guard
            let secondBody = secondBody,
            let contactPoint = contactPoint
        else { return }
        
        blueZ(pos:contactPoint)
        remove(body:secondBody)
    }
    
    func worldVersusLaser(firstBody: SKPhysicsBody?, secondBody: SKPhysicsBody?) {
        guard
            let firstBody = firstBody,
            let secondBody = secondBody
        else { return }
        
        if let firstNode = firstBody.node, let secondNode = secondBody.node, let firstParent = firstNode.parent, let secondParent = secondNode.parent {
            let firstBodyPos = firstNode.scene?.convert(firstNode.position, from: firstParent)
            let secondBodyPos = secondNode.scene?.convert(secondNode.position, from: secondParent)
            
            if firstBody.node != nil {
                firstBody.isDynamic = true
                
                firstBody.linearDamping = CGFloat(50.0) // was 52
                
                guard
                    let x1 = firstBodyPos?.x,
                    let x2 = secondBodyPos?.x,
                    let y1 = firstBodyPos?.y,
                    let y2 = secondBodyPos?.y
                else { return }
                
                var pos = CGFloat(-1)
                if Double(x1) > Double(x2) {
                    pos = CGFloat(1)
                } else if Double(x1) == Double(x2){
                    pos = 0
                }
                
                var turn = CGFloat(-1)
                
                if Double(y1) > Double(y2) {
                    turn = CGFloat(1)
                } else if Double(y1) == Double(y2) {
                    turn = 0
                }
                
                firstBody.applyImpulse(CGVector(dx: 10 * pos, dy: 0))
                firstBody.angularVelocity = 15 * pos * turn
                firstBody.applyTorque(3 * -pos * turn)
                remove(body:secondBody)
            }
        }
    }
    
    func laserVersusFloater(firstBody:SKPhysicsBody?,secondBody:SKPhysicsBody?) {
        guard
            let firstBody,
            let secondBody
        else { return }
        
        if let firstNode = firstBody.node, let secondNode = secondBody.node, let firstParent = firstNode.parent, let secondParent = secondNode.parent {
            let firstBodyPos = firstNode.scene?.convert(firstNode.position, from: firstParent)
            let secondBodyPos = secondNode.scene?.convert(secondNode.position, from: secondParent)
            
            if secondBody.node != nil {
                secondBody.isDynamic = true
                
                secondBody.linearDamping = 50
                secondBody.node?.setScale(1.15)
                
                guard
                    let x1 = firstBodyPos?.x,
                    let x2 = secondBodyPos?.x,
                    let y1 = firstBodyPos?.y,
                    let y2 = secondBodyPos?.y
                else { return }
                
                var pos = CGFloat(-1)
                
                if Double(x1) > Double(x2) {
                    pos = CGFloat(1)
                } else if Double(x1) == Double(x2) {
                    pos = 0
                }
                
                var turn = CGFloat(-1)
                
                if Double(y1) > Double(y2) {
                    turn = CGFloat(1)
                } else if Double(y1) == Double(y2) {
                    turn = 0
                }
                
                secondBody.applyImpulse(CGVector(dx: 10 * pos, dy: 0))
                secondBody.angularVelocity = 15 * pos * turn
                secondBody.applyTorque(3 * -pos * turn)
                remove(body:firstBody)
            }
        }
    }
    
    func baddiePointsHelper(firstBody:SKPhysicsBody?, secondBody:SKPhysicsBody?, contactPoint: CGPoint?) {
        
        guard
            let firstBody,
            let secondBody,
            let contactPoint
        else { return }
        
        guard
            let fbname = firstBody.node?.name
        else { return }
        
        if !fbname.isEmpty {
            let extraPoints = tallyPoints(name: fbname)
            updateScore(extraPoints:extraPoints )
        }
        
        smokeM(pos: contactPoint)
        remove(body: firstBody)
        remove(body: secondBody)
    }

    func remove(body:SKPhysicsBody?) {
        guard
            let b = body,
            let node = b.node as? SKSpriteNode
        else { return }
        
        node.run( SKAction.removeFromParent() )
    }
    
    // Here we are super careful not cause a crash
    func removeNode(node:SKSpriteNode?) {
        guard let n = node else { return }
        
        let r = SKAction.removeFromParent()
        n.run(r)
    }

    func goodiePointsHelper(firstBody:SKPhysicsBody?, secondBody:SKPhysicsBody?, contactPoint: CGPoint?) {
        
        guard
            let firstBody,
            let secondBody,
            let contactPoint
        else { return }
        
        guard
            let sbnn = secondBody.node?.name
        else { return }
        
        if !sbnn.isEmpty {
            let extraPoints = tallyPoints(name: sbnn)
            updateScore(extraPoints:extraPoints )
        }
        
        magicParticle(pos: contactPoint)
        remove(body: firstBody)
        remove(body: secondBody)
    }
    
    func levelUpHelper() {
        level += 1
        
        if highlevel > maxlevel {
            highlevel = maxlevel
        }
        
        if level > highlevel {
            highlevel = level
        }
        
        if level > maxlevel {
            level = 1
        }
        
        world?.speed = 0
        tractor.speed = 0
        
        if settings.music {
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.stop()
            audioPlayer?.volume = 0.0
        }
    }
    
    //MARK: digBeginContact
    func didBegin(_ contact: SKPhysicsContact) {
        guard
            contact.bodyA.categoryBitMask != 0,
            contact.bodyB.categoryBitMask != 0,
            contact.bodyA.node?.parent != nil,
            contact.bodyB.node?.parent != nil,
            contact.bodyA.node != nil,
            contact.bodyB.node != nil,
            contact.bodyA.node?.name != nil,
            contact.bodyB.node?.name != nil
        else { return }
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            secondBody = contact.bodyA
            firstBody = contact.bodyB
        }
        
        let catMask = firstBody.categoryBitMask | secondBody.categoryBitMask
        
        switch catMask {
        case laserbeam | laserBorder :
            
            if let x = firstBody.node?.name {
                if x == "🚩" || x == "💠" {
                    remove(body:firstBody)
                }
            }
            
        case worldCategory | laserbeam :
            
            if firstBody.node?.name == "stone" {
                
                if !firstBody.isDynamic && (secondBody.node?.name == "🔱" || secondBody.node?.name == "💠") {
                    worldVersusLaser(firstBody: firstBody, secondBody: secondBody)
                } else if firstBody.isDynamic && (secondBody.node?.name == "🔱" || secondBody.node?.name == "💠") {
                    baddiePointsHelper(firstBody: firstBody, secondBody: secondBody, contactPoint: contact.contactPoint)
                } else {
                    stoneVersusLaser(secondBody: secondBody, contactPoint: contact.contactPoint)
                }
                
            } else {
                
                if !firstBody.isDynamic {
                    worldVersusLaser(firstBody: firstBody, secondBody: secondBody)
                } else if firstBody.isDynamic {
                    baddiePointsHelper(firstBody: firstBody, secondBody: secondBody, contactPoint: contact.contactPoint)
                } else {
                    worldVersusLaser(firstBody: firstBody, secondBody: secondBody)
                }
            }
            
        case badFishCategory | laserbeam :
            
            if firstBody.isDynamic {
                baddiePointsHelper(firstBody: firstBody, secondBody: secondBody, contactPoint: contact.contactPoint)
            } else {
                worldVersusLaser(firstBody: firstBody, secondBody: secondBody)
            }
            
        case badGuyCategory | laserbeam :
            
            baddiePointsHelper(firstBody: firstBody, secondBody: secondBody, contactPoint: contact.contactPoint)
            
        case laserbeam | itemCategory :
            
            if secondBody.isDynamic {
                goodiePointsHelper(firstBody: firstBody, secondBody: secondBody, contactPoint: contact.contactPoint)
                
            } else {
                laserVersusFloater(firstBody: firstBody, secondBody: secondBody)
            }
            
        case laserbeam | fishCategory :
            
            if secondBody.isDynamic  {
                goodiePointsHelper(firstBody: firstBody, secondBody: secondBody, contactPoint: contact.contactPoint)
            } else {
                laserVersusFloater(firstBody: firstBody, secondBody: secondBody)
            }
            
        case laserbeam | charmsCategory :
            
            goodiePointsHelper(firstBody: firstBody, secondBody: secondBody, contactPoint: contact.contactPoint)
            
        case tractorCategory | itemCategory, tractorCategory | charmsCategory, tractorCategory | fishCategory :
            
            if let prize = secondBody.node as? SKSpriteNode {
                tractorBeamedThisItem(prize: prize)
            }
            
        case heroCategory | levelupCategory :
            
            levelUpHelper()
            
            if secondBody.node?.name == "🌀" {
                if level > 0 && level < 4 {
                    level = 5
                }
            }
            
            saveScores(level: level, highlevel: highlevel, score: score, hscore: highscore, lives: lives)
            
            hero.physicsBody?.velocity = CGVector.zero
            hero.physicsBody?.applyImpulse(CGVector.zero)
            
            let easeOut: SKAction = SKAction.move(to: CGPoint.zero, duration: 0.0)
            easeOut.timingMode = SKActionTimingMode.easeOut
            FlightYoke.run(easeOut)
            FlightYokePilot(velocity: CGVector.zero, zRotation: 0.0)
            
            removeHero()
            removeGUI()
            
            //Loads the LevelUp Scene
            func starPlayrOneLevelUpX(world:SKNode?, hero: SKSpriteNode?, tractor: SKSpriteNode?) {
                
                guard
                    let world = world,
                    let hero = hero,
                    let tractor = tractor
                else { return }
                
                hero.physicsBody?.velocity = CGVector.zero
                hero.physicsBody?.applyImpulse(CGVector.zero)
                hero.speed = 0
                hero.removeFromParent()
                tractor.removeFromParent()
                world.speed = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self else { return }
                    let levelup = LevelUp( size: self.size )
                    levelup.runner()
                    self.size = setSceneSizeForGame()
                    levelup.scaleMode = .aspectFill
                    
                    self.view?.backgroundColor = .black
                    
                    self.view?.isMultipleTouchEnabled = true
                    self.view?.allowsTransparency = false
                    self.view?.isAsynchronous = true
                    self.view?.isOpaque = true
                    self.view?.clipsToBounds = true
                    self.view?.ignoresSiblingOrder = true
                    
                    self.view?.showsFPS = showsFPS
                    self.view?.showsNodeCount = showsNodeCount
                    self.view?.showsPhysics = showsPhysics
                    self.view?.showsFields = showsFields
                    self.view?.showsDrawCount = showsDrawCount
                    self.view?.showsQuadCount = showsQuadCount
                    
                    self.view?.shouldCullNonVisibleNodes = true
                    self.view?.preferredFramesPerSecond = 61
                    
                    self.view?.presentScene(levelup)
                }
            }
            
            starPlayrOneLevelUpX(world:world, hero: hero, tractor: tractor)
            
        case heroCategory | worldCategory, heroCategory | badGuyCategory, heroCategory | badFishCategory :
            
            if ( 🛡 ) {
                return
            }
            
            stopIt(secondBody: secondBody, contactPoint: contact.contactPoint)
        default :
            return
            
        }
    }
    
    var runForestRun = true
    
    func stopIt(secondBody: SKPhysicsBody, contactPoint: CGPoint) {
        Explosion()
        removeHero()
        removeGUI()
        
        //save first
        saveScores(level: level, highlevel: highlevel, score: score, hscore: highscore, lives: lives)
        
        if let world = world, world.speed == 1 && runForestRun {
            world.speed /= 2
            runForestRun = false
            remove(body:secondBody)
            LostLife(contactPoint: contactPoint)
            saveScores(level: level, highlevel: highlevel, score: score, hscore: highscore, lives: lives)
            
            let wait = SKAction.wait(forDuration: 1.5)
            let run = SKAction.run { [ weak self ] in
                guard let self = self else { return }
                self.lives <= 0 ? self.EndGame() : self.RestartLevel()
            }
            
            world.run( SKAction.sequence([wait,run]))
        }
    }
    
    func removeHero() {
        removeNode(node: canape)
        removeNode(node: tractor)
        removeNode(node: hero)
    }
    
    func removeGUI() {
        FlightYoke.alpha = 0 // turn off, update offscreen
        QuadFireBombHUD.alpha = 0
        QuadFireBombHUD.speed = 10
        FlightYoke.recenter()
        FlightYoke.stickMoved(location: CGPoint.zero)
        
        let wait = SKAction.wait(forDuration: 1.0)
        let run = SKAction.run { [ weak self ] in
            guard let self = self else { return }
            self.QuadFireBombHUD.removeAllChildren()
            self.AlienYokeDpdHUD.removeAllChildren()
            self.QuadFireBombHUD.alpha = 1
            self.FlightYoke.alpha = 1 //turn back on before shutdown
            self.FlightYoke.shutdown()
            self.QuadFireBombHUD.speed = 0
        }
        
        world.run( SKAction.sequence([wait,run]))
    }
    
    func LostLife(contactPoint: CGPoint) {
        smokeM(pos: contactPoint)
        
        if settings.music {
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.stop()
            audioPlayer?.volume = 0.0
        }
        
        lives -= 1
        
        if lives >= 0 {
            livesLabelNode.text = String(repeating: heroArray[settings.emoji], count: lives)
        }
        
        saveScores(level: level, highlevel: highlevel, score: score, hscore: highscore, lives: lives)
    }
    
    func EndGame() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            let gameOverScene = GameOver( size: self.size )
            gameOverScene.runner()
            self.size = setSceneSizeForGame()
            gameOverScene.scaleMode = .aspectFill
            
            self.view?.backgroundColor = .black
            self.view?.isMultipleTouchEnabled = true
            self.view?.allowsTransparency = false
            self.view?.isAsynchronous = true
            self.view?.isOpaque = true
            self.view?.clipsToBounds = true
            self.view?.ignoresSiblingOrder = true
            self.view?.showsFPS = showsFPS
            self.view?.showsNodeCount = showsNodeCount
            self.view?.showsPhysics = showsPhysics
            self.view?.showsFields = showsFields
            self.view?.showsDrawCount = showsDrawCount
            self.view?.showsQuadCount = showsQuadCount
            self.view?.shouldCullNonVisibleNodes = true
            self.view?.preferredFramesPerSecond = 61
            self.view?.presentScene(gameOverScene)
        }
    }
    
    func Explosion() {
        guard let hero = hero else { return }
        
        if let explosion = SKEmitterNode(fileNamed: "fireParticle.sks") {
            explosion.alpha = 0.5
            explosion.zPosition = 175
            explosion.position = hero.position
            addChild(explosion)
            
            explosion.run(SKAction.sequence([
                SKAction.scale(to: 0.5, duration: 0.5),
                SKAction.fadeAlpha(to: 0, duration: 0.5),
                SKAction.wait(forDuration: 1.5),
                SKAction.removeFromParent()
            ]))
        }
    }
    
    func RestartLevel() {
        removeHero()
        world.speed = 1
        
        let runResetWorld = SKAction.run() { [ weak self ] in
            guard
                let self = self,
                let world = self.world
            else { return }
            
            let resetWorld = SKAction.moveTo(x: world.position.x, duration: 0.5)
            world.run(resetWorld)
            world.speed = 1
        }
        
        let runWorld = SKAction.run() {  [ weak self ] in
            guard
                let self = self,
                let world = self.world,
                let gamestartup = self.readyPlayerOne()
            else { return }
            
            self.hero = gamestartup.hero
            self.canape = gamestartup.canape
            self.tractor = gamestartup.tractor
            
            if settings.emoji == 2 {
                self.emojiAnimation(emojis:["🙈","🙊","🙉","🐵"])
            }
            
            self.bombsbutton  =  gamestartup.bombsbutton
            self.firebutton   = gamestartup.firebutton
            self.bombsbutton2 = gamestartup.bombsbutton2
            self.firebutton2  = gamestartup.firebutton2
            
            if settings.music {
                self.audioPlayer?.numberOfLoops = -1
                self.audioPlayer?.play()
                self.audioPlayer?.volume = 1.0
            } else {
                self.audioPlayer?.numberOfLoops = 0
                self.audioPlayer?.stop()
                self.audioPlayer?.volume = 0.0
            }
            
            world.speed = 1
            
            self.runForestRun = true
        }
        
        let wait = SKAction.wait(forDuration: 0.5)
        world.run(SKAction.sequence([wait,runResetWorld,wait,runWorld]))
    }
    
    // Find the Score
    // And return 1 if we can't find it
    func tallyPoints(name:String?) -> Int {
        guard let name = name else {
            return(0)
        }
        
        if name.isEmpty {
            return(0)
        }
        
        let pts = 1
        
        if name == "❣️" && lives >= 0 && lives < 9 {
            lives += 1
            
            if lives > maxlives {
                lives = maxlives
            }
            
            livesLabelNode.text = String(repeating: heroArray[settings.emoji], count: lives)
                    
            if settings.sound {
                let fire: SKAction = SKAction.playSoundFileNamed("extralife.m4a", waitForCompletion: false)
                self.run(fire)
            }
        }
        
        //gives our ship shields
        if name == "🛡"  {
            /* Power Ups */
            🛡 = true
            
            if let l = livesLabel.text, !l.contains("🛡") {
                livesLabel.text? += "🛡"
                
                hero.alpha = 0.75
                
                //MARK: aura particle emitter
                if let aura = SKEmitterNode(fileNamed: "aura") {
                    aura.alpha = 0.25
                    aura.speed = 1
                    aura.name = "aura"
                    aura.setScale(0.5)
                    hero.addChild(aura)
                }
            }
            
            if settings.sound {
                let fire: SKAction = SKAction.playSoundFileNamed("doublelaser.m4a", waitForCompletion: false)
                self.run(fire)
            }
        }
        
        //gives our ship double lasers
        if name == "🔫" {
            doublelaser = 1
            
            if let l = livesLabel.text, !l.contains("🔫") {
                livesLabel.text! += "🔫"
            }
 
            if settings.sound {
                let fire: SKAction = SKAction.playSoundFileNamed("doublelaser.m4a", waitForCompletion: false)
                self.run(fire)
            }
        }
        
        //gives our ship superman lasers
        if name == "💠" || name == "💎" {
            💠 = true
            
            if let l = livesLabel.text, !l.contains("💠") {
                livesLabel.text! += "💠"
            }
            
            if settings.sound {
                let fire: SKAction = SKAction.playSoundFileNamed("doublelaser.m4a", waitForCompletion: false)
                self.run(fire)
            }
        }
        
        //gives our trident bombs
        if name == "🔱" {
            🔱 = true
            
            if let l = livesLabel.text, !l.contains("🔱") {
                livesLabel.text? += ("🔱")
            }
            
            if settings.sound {
                let fire: SKAction = SKAction.playSoundFileNamed("doublelaser.m4a", waitForCompletion: false)
                self.run(fire)
            }
        }
        
        if name == "🕹" && !settings.rapidfire  {
            🕹 = true
            doublelaser = 1
            settings.rapidfire = true
            if let l = livesLabel.text, !l.contains("🕹") {
                livesLabel.text? += "🕹"
            }
            
            if settings.sound {
                let fire: SKAction = SKAction.playSoundFileNamed("doublelaser.m4a", waitForCompletion: false)
                self.run(fire)
            }
        }
        
        /* guard did not stop from crashing, so using this instead */
        if let score = (scoreDict[name]) {
            return score
        } else {
            print("if let score found : missing score for: " + name)
            return (pts)
        }
    }
    
    //MARK: UpdateScore
    func updateScore(extraPoints:Int) {
        
        self.score = self.score + extraPoints
        
        if self.score >= self.highscore {
            self.highscore = self.score
            self.highScoreLabelNode.text = String(self.highscore)
        }
        
        self.scoreLabelNode.text = String(self.score)
        
        if world?.speed == 0 {
            saveScores(level: self.level, highlevel: self.highlevel, score: self.score, hscore:self.highscore, lives: self.lives)
        }
    }
    
    //MARK: Game Projectiles
    
    func laserbeak (superhero: (position:CGPoint, zRotation: CGFloat, velocity: CGVector), reverse: Bool) {
        
        guard let 🧵 = 💠 ? 🥾 + 🦸 : 🦸 else { return }

        // Reuse the cached laser texture for this mode instead of allocating a
        // fresh SKTexture per shot. The monkey branch below overwrites 👁, so
        // the cache is populated once per mode and reused harmlessly afterward.
        if 💠 {
            if superLaserTex == nil { superLaserTex = SKTexture(imageNamed: 🧵) }
            👁 = SKSpriteNode(texture: superLaserTex)
        } else {
            if laserTex == nil { laserTex = SKTexture(imageNamed: 🧵) }
            👁 = SKSpriteNode(texture: laserTex)
        }
        
        var 👨‍🔬 = SKPhysicsBody(rectangleOf: 👁.size)
        
        
        //Monkey
        if settings.emoji == 2 {
            👁.physicsBody?.applyAngularImpulse(5)
            // 🛥 ? (🍕 = 1) : (🍕 = -1)
            
            //let texture = SKTexture.init(image: self.transparentimage)
            👁 = SKSpriteNode()
            👨‍🔬 = SKPhysicsBody(circleOfRadius: 🍺)
            let 🔫: SKLabelNode = SKLabelNode(fontNamed:emojifontname)
            
            🔫.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
            🔫.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
            🔫.text = 🍌
            🔫.fontSize = 32
            👁.addChild(🔫)
        }
        
        💠 ? (👁.name = "💠") : (👁.name = "🚩")
        
        👁.isUserInteractionEnabled = false
        👁.physicsBody = 👨‍🔬
        👁.physicsBody?.mass = 0
        👁.zPosition = -100
        👁.physicsBody?.fieldBitMask = 0
        👁.physicsBody?.isDynamic = true
        👁.physicsBody?.affectedByGravity = false
        👁.physicsBody?.allowsRotation = true
        👁.physicsBody?.categoryBitMask = laserbeam
        👁.physicsBody?.collisionBitMask = laserBorder

        let x = 3994 //calculated 2 + 8 + 16 + 128 + 256 + 512 + 1024 + 2048
        👁.physicsBody?.contactTestBitMask = UInt32(x)
        👁.physicsBody?.density = 0
        👁.physicsBody?.fieldBitMask = 0
        👁.physicsBody?.restitution = 0
        👁.physicsBody?.applyImpulse(CGVector(dx: 100,dy: 0))
        👁.speed = CGFloat(0.8)
        👁.physicsBody?.usesPreciseCollisionDetection = false
        let superheroPositionX = superhero.position.x
        
        if doublelaser == 1 && settings.emoji != 2 {
            👁.position = (CGPoint(x:superheroPositionX, y:superhero.position.y - 5))
        } else if doublelaser == 1 && settings.emoji == 2 {
            👁.position = (CGPoint(x:superheroPositionX, y:superhero.position.y - 16))
        } else {
            👁.position = superhero.position
        }
        
        let rotateLaser = superhero.zRotation * -3
        let constantX = CGFloat(750)
        let constantY = CGFloat(250)
        let uno = CGFloat(1)
        
        let d = reverse ? (x : -uno, y : uno) : (x : uno, y : -uno)
        
        👁.physicsBody?.velocity = CGVector( dx: d.x * constantX + superhero.velocity.dx, dy: rotateLaser * d.y * constantY + superhero.velocity.dy )
        
        👁.zRotation = superhero.zRotation
        
        let laserDupe = 👁.copy() as! SKSpriteNode
        addChild(laserDupe)
        
        if settings.emoji == 2 {
            let decay = SKAction.wait(forDuration: TimeInterval(0.6 * Double(settings.mode)))
            let spin = SKAction.rotate(byAngle: CGFloat.pi * 3.0 * 🍕, duration: 2)
            let spin2 = SKAction.rotate(byAngle: CGFloat.pi * -3.0 * 🍕, duration: 2)

            let remove = SKAction.removeFromParent()
            laserDupe.run(SKAction.sequence([spin,decay,remove]))
            👁.run(SKAction.sequence([spin2,decay,remove]))

        } else {
            let decay = SKAction.wait(forDuration: TimeInterval(0.6 * Double(settings.mode)))
            let remove = SKAction.removeFromParent()
            laserDupe.run(SKAction.sequence([decay,remove]))
        }
        
        //MARK: Power Up that lasts the entire level!
        if doublelaser == 1 {
            let laser2 = 👁.copy()
            (laser2 as! SKSpriteNode).position = (CGPoint(x:superheroPositionX, y:superhero.position.y + 5))
            addChild(laser2 as! SKSpriteNode)
        }
        
        if settings.sound {
            let fire: SKAction = SKAction.playSoundFileNamed(🚨, waitForCompletion: false)
            laserDupe.run(fire)
        }
    }
    
    func bombaway (superhero: (position:CGPoint, zRotation: CGFloat, velocity: CGVector), reverse: Bool ) {
        
        💣 = SKSpriteNode()
        💣.position = (CGPoint(x:superhero.position.x, y:superhero.position.y - 10))
        
        //MARK: How to assign values in an Elvis Operator
        
        🔱 ? (💣.name = "🔱") : (💣.name = "💣")
        
        💣.isUserInteractionEnabled = false
        💣.physicsBody = 🦞
        💣.physicsBody?.affectedByGravity = true
        💣.physicsBody?.isDynamic = true
        💣.physicsBody?.affectedByGravity = true
        💣.physicsBody?.allowsRotation = true
        💣.physicsBody?.categoryBitMask = 64
        💣.physicsBody?.collisionBitMask = 4
        
        let x = 2 + 8 + 16 + 128 + 256 + 512 + 1024 + 2048
        💣.physicsBody?.contactTestBitMask = UInt32(x)
        
        💣.physicsBody?.applyImpulse(CGVector(dx: 0,dy: 50))
        💣.physicsBody?.density = 0
        💣.physicsBody?.fieldBitMask = 0
        💣.physicsBody?.applyAngularImpulse(20)
        💣.physicsBody?.restitution = 0.5
        
        // Bomb self-reap timeout. NOTE: DaBomb is a copy of 💣, which has
        // .speed = 200 (set below before the copy). SKNode.speed is an
        // action-time multiplier that propagates to the node + its children, so
        // wait(forDuration:) is DIVIDED by 200 — 800 here is NOT 800 seconds,
        // it's 800/200 ≈ 4 real seconds, enough for the bomb to finish its arc
        // before it's reaped. (A literal 8 reaps the bomb in 8/200 = 0.04s, so
        // it vanishes the instant it's fired — looks like "the bombs don't leave".)
        let wait: TimeInterval = 800
        
        if reverse {
            💣.physicsBody?.velocity = CGVector( dx: superhero.velocity.dx / 4, dy: 350)
        } else {
            💣.physicsBody?.velocity = CGVector( dx: superhero.velocity.dx / 4, dy: -350)
        }
        
        🧨.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
        🧨.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
        
        🔱 ? (🧨.text = "🔱") : (🧨.text = "💩")
        
        🔱 && !reverse ? (🧨.yScale = -1) : ()
        
        🧨.fontSize = 32
        💣.addChild(🧨)
        💣.speed = 200
        
        let DaBomb = 💣.copy() as! SKSpriteNode
        addChild(DaBomb)
        
        let decay = SKAction.wait(forDuration: TimeInterval(wait))
        let remove = SKAction.removeFromParent()
        DaBomb.run(SKAction.sequence([decay,remove]))
        
        if settings.sound {
            let bombs: SKAction = SKAction.playSoundFileNamed(💥, waitForCompletion: false)
            DaBomb.run(bombs)
        }
    }
    
    func firebomb(firebomb:SKSpriteNode) {
        let fadeIn = SKAction.fadeAlpha(to: 0.5, duration:TimeInterval(0.3))
        let myDecay = SKAction.wait(forDuration: 0.5)
        let fadeOut = SKAction.fadeAlpha(to: 0.0001, duration:TimeInterval(0.6))
        firebomb.run(SKAction.sequence([fadeIn,myDecay,fadeOut]))
    }
 }
 
