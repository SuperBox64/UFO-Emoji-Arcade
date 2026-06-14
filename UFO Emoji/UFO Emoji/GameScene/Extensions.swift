//
//  Extensions.swift
//  UFO Emoji
//
//  Created by Todd Bruss on 10/16/24.
//  Copyright © 2026 Todd Bruss. All rights reserved.
//

import SpriteKit

extension SKSpriteNode {
   func addGlow(radius: Float = 64) {
       let effectNode = SKEffectNode()
       effectNode.addChild(SKSpriteNode(texture: texture))
       effectNode.filter = CIFilter( name: "CIMotionBlur", parameters: [ "inputRadius":radius,"inputAngle": CGFloat.pi / 2 ] )
       effectNode.shouldRasterize = true
       addChild(effectNode)
   }
}
