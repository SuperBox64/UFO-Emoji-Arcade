//
//  LevelUp.swift
//  UFO Emoji
//
//  Created by Todd Bruss on 12/7/15, Updated Oct 15, 2024.
//  Copyright (c) 2026 Todd Bruss. All rights reserved.
//

import SpriteKit

class LevelUp: SKScene {
    weak var gd = gameDelegate

     override init(size: CGSize ) {
        super.init(size: size)
        
        self.removeAllActions()
        self.removeAllChildren()
        self.removeFromParent()
        
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
    
    func runner () {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
     
            self.anchorPoint = CGPoint(x: 0.0, y: 0.0)
            
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
            
            let lives = loadScores().lives
            let heroMessage = levelarray[settings.level]
            let enemyMessage = antiarray[settings.level]
            let livesMessage = String(repeating: heroArray[settings.emoji], count: lives)

            self.backgroundColor = .black
            
            let label = SKLabelNode(fontNamed: emojifontname)
            label.text = heroMessage
            label.fontSize = 72
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.xScale = -1
            label.position = CGPoint(x: self.size.width / 2 - 48, y: self.size.height / 2 + 72)
            self.addChild(label)
            
            let label3 = SKLabelNode(fontNamed: emojifontname)
            label3.text = enemyMessage
            label3.fontSize = 72
            label3.horizontalAlignmentMode = .center
            label3.verticalAlignmentMode = .center
            label3.position = CGPoint(x: self.size.width/2 + 48, y: self.size.height / 2 + 72)
            self.addChild(label3)
            
            let label2 = SKLabelNode(fontNamed: emojifontname)
            label2.text = livesMessage
            label2.fontSize = 64
            label2.horizontalAlignmentMode = .center
            label2.verticalAlignmentMode = .center
            label2.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2 - 72)
            self.addChild(label2)
               
        }
		
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.gd?.runGameLevel()
        }
    }
        
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
