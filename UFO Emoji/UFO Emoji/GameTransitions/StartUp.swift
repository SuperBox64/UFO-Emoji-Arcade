//
//  GameOver.swift
//  UFO Emoji
//
//  Created by Todd Bruss on 12/7/15, Updated Oct 15, 2024.
//  Copyright (c) 2026 Todd Bruss. All rights reserved.
//

import SpriteKit

class StartUp: SKScene {
    
    weak var gd = gameDelegate

    override init(size: CGSize) {
        super.init(size: size)
    }
    
    deinit {

        if hasActions() {
            removeAllActions()
        }
        
        if !children.isEmpty {
            removeAllChildren()
        }
        
        removeFromParent()
    }
    
    func runner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
        
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
            self.anchorPoint = CGPoint(x: 0.0, y: 0.0)
            self.backgroundColor = .black
            
            let mainCharacter = heroArray[settings.emoji]
            let goodGuy = levelarray[settings.level]
            let badGuy = antiarray[settings.level]
                        
            let label1 = SKLabelNode(fontNamed: emojifontname)
            label1.fontSize = 72
            label1.text = mainCharacter
            label1.horizontalAlignmentMode = .center
            label1.verticalAlignmentMode = .center
            label1.position = CGPoint(x: self.size.width / 2 - 120, y: self.size.height / 2 )
            self.addChild(label1)
            
            let label2 = SKLabelNode(fontNamed: emojifontname)
            label2.fontSize = 72
            label2.text = goodGuy
            label2.xScale = -1
            label2.horizontalAlignmentMode = .center
            label2.verticalAlignmentMode = .center
            label2.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
            self.addChild(label2)
            
            let label3 = SKLabelNode(fontNamed: "Apple Color Emoji")
            label3.fontSize = 72
            label3.text = badGuy
            label3.horizontalAlignmentMode = .center
            label3.verticalAlignmentMode = .center
            label3.position = CGPoint(x: self.size.width / 2 + 120, y: self.size.height / 2)
            self.addChild(label3)
        }

        // Linger on the matchup intro before starting the level (the original
        // plain `async` fired next tick → the scene was set up and replaced in the
        // same frame → a 1-frame flash). LevelUp uses asyncAfter(2.0); match that
        // intent so the StartUp screen actually shows like the level-up screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.gd?.runGameLevel()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
