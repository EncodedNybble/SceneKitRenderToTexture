//
//  SpriteKitAnimationScene.swift
//  SceneKitRenderToTexture
//
//  Copyright © 2016 NybbleGames. All rights reserved.
//

import SpriteKit

class SpriteKitAnimationScene: SKScene {

    override init() {
        super.init()

        self.setup()
    }

    override init(size: CGSize) {
        super.init(size: size)

        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {

        let atlas = SKTextureAtlas(named:"BearImages")

        let numImages = atlas.textureNames.count;
        var animFrames:[SKTexture] = []
        let sortedTextureNames = atlas.textureNames.sort()

        var index:Int = 0
        while index < numImages {
            let temp:SKTexture = atlas.textureNamed(sortedTextureNames[index])
            animFrames.append(temp)

            index += 2
        }

        let temp:SKTexture = animFrames[0]
        let sprite:SKSpriteNode = SKSpriteNode(texture: temp)

        sprite.position = CGPointMake(self.scene!.size.width/2, self.scene!.size.height/2)
        sprite.runAction(SKAction.repeatActionForever(SKAction.animateWithTextures(animFrames, timePerFrame: 0.1)))

        self.addChild(sprite)
        self.backgroundColor = UIColor.clearColor()
    }
}
