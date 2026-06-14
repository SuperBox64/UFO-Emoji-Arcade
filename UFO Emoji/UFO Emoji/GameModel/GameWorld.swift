//
//  GameWorld.swift
//  UFO Emoji
//
//  Created by Todd Bruss on 5/28/20, Updated Oct 15, 2024.
//  Copyright (c) 2026 Todd Bruss. All rights reserved.
//

import SpriteKit

class GameWorld : SKNode {
    private weak var world : SKNode!
    private var gameTileMapRun : GameTileMapRun!
    
    init(world: SKNode ) {
        super.init()
        self.world = world
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        world = nil
    }
    
    func gameLevel(filename: String) -> SKNode {
        //Check if level exists first (safe)
        guard
            var referenceNode = SKReferenceNode.init(fileNamed: filename),
            let level = referenceNode.children.first?.children
            else { return world }

        referenceNode.name = "🥶🥶🥶"
        referenceNode.position = CGPoint(x:0,y:0)
        
        world.addChild(referenceNode )
        
        for var land in level {
            
            if let name = land.name {
                if var tileMap = referenceNode.childNode(withName: "//" + name ) as? SKTileMapNode {
                    
                    if name == "Water" {
                        tileMap.removeAllActions()
                        tileMap.physicsBody = nil
                        tileMap.name = ""
                        land.removeAllActions()
                        land.alpha = 0.4
                        land.name = ""
                        land.zPosition = 1000
                    } else {
                        setupLevel( tileMap: tileMap)
                        tileMap.removeAllActions()
                        tileMap.removeAllChildren()
                        tileMap.removeFromParent()
                        //Tear down
                        tileMap = SKTileMapNode()
                        tileMap.tileSet = SKTileSet.init()
                        tileMap.tileSize = CGSize.zero
                        
                        land.removeAllActions()
                        land.removeAllChildren()
                        land.removeFromParent()
                        land = SKNode()
                    }
                }
            }
        }
        
        referenceNode = SKReferenceNode()
        referenceNode.resolve()
        
        return world
    }
    
    func setupLevel(tileMap: SKTileMapNode) {
        tileMap.alpha = 0.0
    	gameTileMapRun = GameTileMapRun(TileMapTileSize: tileMap.tileSize, TileMapParent: tileMap.parent?.parent, TileMapRect: tileMap.scene?.frame)
        for col in (0 ..< tileMap.numberOfColumns) {
            for row in (0 ..< tileMap.numberOfRows) {
                let tileDefinition = tileMap.tileDefinition(atColumn: col, row: row)
                let center = tileMap.centerOfTile(atColumn: col, row: row)
                tileDefinition?.textures.removeAll()
                
                if let td = tileDefinition, let n = td.name, !n.isEmpty, let g = gameTileMapRun {
                    g.tileMapRun(tileDefinition: td, center: center)
                    td.textures.removeAll()
                }
                
                //MARK: Destroy even more stuff
                let tileTexture = [SKTexture()]
            	let tileDef = SKTileDefinition(textures: tileTexture, size: CGSize.zero, timePerFrame: 0.0)
                let tileGroup = SKTileGroup.empty()
                tileMap.setTileGroup(tileGroup, andTileDefinition:tileDef, forColumn: col, row: row)
            }
        }
        
        tileMap.removeAllActions()
        tileMap.removeAllChildren()
        
        gameTileMapRun = nil
    }
}
