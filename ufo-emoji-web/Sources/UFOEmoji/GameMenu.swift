//
//  GameMenu.swift
//  UFO Emoji
//
//  Created by Todd Bruss on 12/3/15, Updated Oct 15, 2024.
//  Copyright (c) 2026 Todd Bruss. All rights reserved.
//

import SpriteKit

class GameMenu: SKScene {
    private var minlevel : Int! = 1
    private var maxEmoji : Int! = 3
    private var minEmoji : Int! = 1
    private var musicLabel : SKLabelNode! = SKLabelNode(fontNamed: emojifontname)
    private var soundLabel : SKLabelNode! = SKLabelNode(fontNamed: emojifontname)
    private var stickLabel : SKLabelNode! = SKLabelNode(fontNamed: emojifontname)
    private var levelLabel : SKLabelNode! = SKLabelNode(fontNamed: emojifontname)
    private var versusLabel : SKLabelNode! = SKLabelNode(fontNamed: emojifontname)
    private var emojiLabel : SKLabelNode! = SKLabelNode(fontNamed: emojifontname)
    private var playLabel1 : SKLabelNode! = SKLabelNode(fontNamed: emojifontname)
    private var playLabel2 : SKLabelNode! = SKLabelNode(fontNamed: emojifontname)
    private var playNode : SKNode! = SKNode()
    private var lockDown : Bool! = false
    
    deinit {
        if hasActions() {
            removeAllActions()
        }
        
        if !children.isEmpty {
            removeAllChildren()
        }
    
        removeFromParent()
        
        minlevel    = nil
        maxEmoji    = nil
        minEmoji    = nil
        musicLabel 	= nil
        soundLabel 	= nil
        stickLabel 	= nil
        levelLabel 	= nil
        versusLabel = nil
        emojiLabel 	= nil
        playLabel1 	= nil
        playLabel2 	= nil
        playNode 	= nil
        lockDown    = nil
    }
    
    internal override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if settings.highlevel > maxlevel {
            settings.highlevel = maxlevel
        }
        
        super.touchesBegan(touches as Set<UITouch>, with: event)
        
        for touch in touches {
            let location: CGPoint = touch.location(in: self)
            let touchedNode = atPoint(location)
            
            if let name = touchedNode.name {
                
                if name == "music-left" || name == "music-right" || name == "musicLabel" {
                    settings.music = !settings.music //toggle
                    musicLabel.text = settings.music ? "🎷🔈" : "🎷🔇"
                }
                
                if name == "sound-left" || name == "sound-right" || name == "soundLabel" {
                    settings.sound = !settings.sound
                    soundLabel.text = settings.sound ? "💥🔔" : "💥🔕"
                }
                
                if name == "stick-left" || name == "stick-right" || name == "stickLabel" {
                    settings.stick = !settings.stick
                    stickLabel.xScale = settings.stick ? -1 : 1
                }
                
                if name == "level-right" || name == "levelLabel" || name == "versusLabel" {
                    
                    if settings.level <= settings.highlevel {
                        settings.level = settings.level + 1
                    }
                    
                    if settings.level <= settings.highlevel  {
                        levelLabel.text = levelarray[settings.level]
                        versusLabel.text = antiarray[settings.level]
                    } else {
                        settings.level = minlevel
                        levelLabel.text = levelarray[settings.level]
                        versusLabel.text = antiarray[settings.level]
                    }
                }
                
                if name == "level-left" {
                    if settings.level >= minlevel {
                        settings.level = settings.level - 1
                    }
                    
                    if settings.level >= minlevel  {
                        levelLabel.text = levelarray[settings.level]
                        versusLabel.text = antiarray[settings.level]
                    } else {
                        settings.level =  settings.highlevel
                        levelLabel.text = levelarray[settings.level]
                        versusLabel.text = antiarray[settings.level]
                    }
                }
                
                if name == "emo-right" || name == "emojiLabel" {
                    if settings.emoji <= maxEmoji {
                        settings.emoji = settings.emoji + 1
                    }
                    
                    if settings.emoji  <= maxEmoji {
                        emojiLabel.text = heroDisplay[settings.emoji]
                        playLabel1.text = heroArray[settings.emoji]
                    } else {
                        settings.emoji  = minEmoji
                        emojiLabel.text = heroDisplay[settings.emoji]
                        playLabel1.text = heroArray[settings.emoji]
                    }
                }
                
                if name == "emo-left" {
                    if settings.emoji >= minEmoji {
                        settings.emoji = settings.emoji - 1
                    }
                    
                    if settings.emoji >= minEmoji  {
                        emojiLabel.text = heroDisplay[settings.emoji]
                        playLabel1.text = heroArray[settings.emoji]
                    } else {
                        settings.emoji = maxEmoji
                        emojiLabel.text = heroDisplay[settings.emoji]
                        playLabel1.text = heroArray[settings.emoji]
                    }
                }
                
                if (name == "play" || name == "playbutton") && !lockDown {
                    lockDown = true
                    
                    if settings.highlevel > maxlevel {
                        settings.highlevel = maxlevel
                    }
                    
                    if settings.level == 0 {
                        settings.level = 1
                    }
                    
                    let fadeIn = SKAction.fadeAlpha(to: 0.5, duration:TimeInterval(0.3))
                    let myDecay = SKAction.wait(forDuration: 0.2)
                    let fadeOut = SKAction.fadeAlpha(to: 1.0, duration:TimeInterval(0.3))
                    
                    playNode.run(SKAction.sequence([fadeIn,myDecay,fadeOut]))
                  
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                        guard let self = self else { return }
                      
                        let startup = StartUp( size: self.size )
                        startup.runner()
                        self.size = setSceneSizeForGame()
                        startup.scaleMode = .aspectFit
                        
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
                        self.view?.presentScene(startup)
                        self.lockDown = false
                    }
                } else if name != "musicLabel" && name != "soundLabel" && name != "stickLabel" && name != "levelLabel" && name != "versusLabel" && name != "emojiLabel" {
                    let fadeIn = SKAction.fadeAlpha(to: 0.5, duration:TimeInterval(0.1))
                    let myDecay = SKAction.wait(forDuration: 0.1)
                    let fadeOut = SKAction.fadeAlpha(to: 0.25, duration:TimeInterval(0.1))
                    touchedNode.run(SKAction.sequence([fadeIn,myDecay,fadeOut]))
                }
            }
        }
    }
    
    internal override func didMove(to view: SKView) {
        KingQueenGlobalDie = 100
        backgroundColor = SKColor.init(displayP3Red: 0, green: 15 / 255, blue: 70 / 255, alpha: 1.0)
        
        if settings.level > maxlevel {
            settings.level = 1
        }
               
        settings.lives = minlives
        settings.score = 0
    
        musicLabel.text = settings.music  ? "🎷🔈" : "🎷🔇"
        soundLabel.text = settings.sound ? "💥🔔" : "💥🔕"
        stickLabel.text = "👉🕹"
        
        stickLabel.xScale = settings.stick ? -1 : 1
        levelLabel.text = levelarray[settings.level]
        versusLabel.text = antiarray[settings.level]
        
        let spc 	 = CGFloat(100)
        let alphaDog = CGFloat(0.25)
        let fontSize = CGFloat(48.0)
        
        //MARK: Draw Menu replaces our Struct (So we don't have the carry the Scene in to the Struct)
        func drawMenu(_ name: String, label: SKLabelNode, spriteNode: String, spriteName: String, emojiName: String, spriteNodeB: String, spriteNameB: String, versusLabel: SKLabelNode? = nil) {
            
            if let childNode = scene?.childNode(withName: name) {
                let sprite = SKSpriteNode(imageNamed: spriteNode)
                
                sprite.alpha = alphaDog
                sprite.position = childNode.position
                sprite.position.x = sprite.position.x + -spc
                sprite.name = spriteName
                
            	addChild(sprite)
                
                label.fontName = emojifontname
                label.fontSize = fontSize
                label.name = emojiName
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                
                if versusLabel == nil {
                    label.position = childNode.position
                } else {
                    label.position.y = childNode.position.y
                    label.position.x = childNode.position.x + -28
                    label.xScale = -1
                }
                
                addChild(label)
                
                let spriteB = SKSpriteNode(imageNamed: spriteNodeB)
                
                spriteB.alpha = alphaDog
                spriteB.position = childNode.position
                spriteB.position.x = sprite.position.x + (spc * 2)
                spriteB.name = spriteNameB
                addChild(spriteB)
                
                if let versusLabel = versusLabel {
                    versusLabel.name = "versusLabel"
                    versusLabel.fontSize = fontSize
                    versusLabel.horizontalAlignmentMode = .center
                    versusLabel.verticalAlignmentMode = .center
                    versusLabel.position = childNode.position
                    versusLabel.position.x = versusLabel.position.x + 28
                    
                    addChild(versusLabel)
                }
            }
        }
        
        //Draw our GUI
        drawMenu("emoji", label: emojiLabel, spriteNode: "menu-left", spriteName: "emo-left", emojiName: "emojiLabel", spriteNodeB: "menu-right", spriteNameB: "emo-right")
        drawMenu("ship", label: stickLabel, spriteNode: "menu-left", spriteName: "stick-left", emojiName: "stickLabel", spriteNodeB: "menu-right", spriteNameB: "stick-right")
        drawMenu("level", label: levelLabel, spriteNode: "menu-left", spriteName: "level-left", emojiName: "levelLabel", spriteNodeB: "menu-right", spriteNameB: "level-right", versusLabel: versusLabel)
        drawMenu("music", label: musicLabel, spriteNode: "menu-left", spriteName: "music-left", emojiName: "musicLabel", spriteNodeB: "menu-right", spriteNameB: "music-right")
        drawMenu("sound", label: soundLabel, spriteNode: "menu-left", spriteName: "sound-left", emojiName: "soundLabel", spriteNodeB: "menu-right", spriteNameB: "sound-right")
        
        //🤾‍♀️🏏⚽️⚾️
        
        if let pn = childNode(withName: "play") {
            addChild(playNode)
            playNode.position = pn.position
            
            playNode.position.x = playNode.position.x + spc - 16
            let playLabel = SKLabelNode(fontNamed: emojifontname)
            playLabel.text = "🎮"
            playLabel.fontSize = 48
            playLabel.horizontalAlignmentMode = .center
            playLabel.verticalAlignmentMode = .center
            playLabel.name = "play"
            playLabel.position = CGPoint(x:(-spc * 1.5) - 33,y:0)
            playNode.addChild(playLabel)
            
            playLabel1.text = heroArray[settings.emoji]
            playLabel1.fontSize = 48
            playLabel1.horizontalAlignmentMode = .center
            playLabel1.verticalAlignmentMode = .center
            playLabel1.name = "play"
            
            playLabel2.text = "🌎"
            playLabel2.fontSize = 44
            playLabel2.horizontalAlignmentMode = .center
            playLabel2.verticalAlignmentMode = .center
            playLabel2.alpha = 1.0
            playLabel2.name = "play"
            
            let subtext = SKLabelNode(fontNamed: "Emulogic")
            
            subtext.text = ""
            subtext.fontSize = 32
            subtext.horizontalAlignmentMode = .center
            subtext.verticalAlignmentMode = .center
            subtext.name = name
            subtext.zPosition = 101
            subtext.alpha = 0.5
            subtext.fontColor = UIColor.white
            playNode.addChild(subtext)
            subtext.position = CGPoint(x:-(spc / 2) - 19.25,y:1.5)
            
            let sprite = SKSpriteNode(imageNamed: "playbutton")
            sprite.alpha = 1.0
            playNode.addChild(sprite)
            sprite.name = "playbutton"
            sprite.position = CGPoint(x:0,y:0)
            playNode.addChild(playLabel1)
            playNode.addChild(playLabel2)
            playLabel1.position = CGPoint(x:-spc - 27,y:0)
            playLabel2.position = CGPoint(x:-(spc / 2) - 20,y:0)
        }
        
        levelLabel.text  = levelarray  [settings.level]
        versusLabel.text = antiarray   [settings.level]
        emojiLabel.text  = heroDisplay [settings.emoji]
        playLabel1.text  = heroArray   [settings.emoji]
    }
}
