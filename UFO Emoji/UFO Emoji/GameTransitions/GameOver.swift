//
//  GameOver.swift
//  UFO Emoji
//
//  Created by Todd Bruss on 12/7/15, Updated Oct 15, 2024.
//  Copyright (c) 2026 Todd Bruss. All rights reserved.
//

import SpriteKit


class GameOver: SKScene {
    
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
            
            self.anchorPoint = CGPoint(x: 0.5, y: 0.5)

            let my = loadScores()
            var scorelabel = "🎲"
            
            if my.score == my.hscore {
                scorelabel = "💎"
            }
        
            let message = "🎯 " + scorelabel
            
            self.backgroundColor = .black
            
            /* Game Over Message */
            let label = SKLabelNode(fontNamed: emojifontname)
            label.text = message
            label.fontSize = 68
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 64 )
            
            /* Show the Score */
            let label2 = SKLabelNode(fontNamed: "Emulogic")
            label2.text = String( my.score )
            label2.fontSize = 34
            label2.horizontalAlignmentMode = .center
            label2.verticalAlignmentMode = .center
            label2.fontColor = SKColor.white
            label2.position = CGPoint(x: 0, y: -64)
            
            self.addChild(label)
            self.addChild(label2)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.gd?.runGameMenu()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
