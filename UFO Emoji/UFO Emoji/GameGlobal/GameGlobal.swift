//
//  Global.swift
//  UFO Emoji
//
//  Created by Todd Bruss on 5/24/20, Updated Oct 15, 2024.
//  Copyright (c) 2026 Todd Bruss. All rights reserved.
//

//Could could start moving this into a Struct

import SpriteKit

typealias appsettings =  (level: Int, highlevel: Int, emoji: Int, score: Int, highscore: Int, lives: Int, music: Bool, sound: Bool, stick: Bool, mode: Int, rapidfire: Bool)
var settings : appsettings = (level: 1, highlevel: 2, emoji: 1, score: 0, highscore: 0, lives: 3, music: true, sound: true, stick: true, mode: 0, rapidfire: false)

var levelarray: Array = ["🦕","🦕","😎","🚙","🦋", "🐮", "🕊","🦆","🍀","🕸", "🥥", "🐿","💐","🦄","🐴","🐶","🐌","🐄","🐄"]

var antiarray : Array = ["🦖","🦖","😡","🚗","🐛", "🐔", "🐍","🦅","🎱","🕷", "🌴", "🦔","🍄","🐺","🐗","🐱","🦂","🐓","🐓"]

var heroArray: Array = ["👽","👽","🐵","💩","💩"]
var heroDisplay: Array = ["🛸👽","🛸👽","🚀🐵","🚀💩","🚀💩"]
var livesDisplay = ["👽"]

let minlives = 3
let maxlives = 9
let maxlevel = 12
var doublelaser = 0
var 🔱 = false
var 🛡 = false
var 💠 = false
var 🕹 = false

var KingQueenGlobalDie = 100
var emojifontname = "Apple Color Emoji" //"Toddmoji" //"Segoe UI Emoji" //"EmojiOneColor"//     "Apple Color Emoji" //"Segoe UI Emoji"
var gameDelegate : GameProtocol?

let showsFPS        = false
let showsNodeCount  = false
let showsPhysics    = false
let showsFields     = false
let showsDrawCount  = false
let showsQuadCount  = false

func loadScores() -> (level: Int, highlevel: Int, score: Int, hscore: Int, lives: Int) {
    let hscore = settings.highscore
    let highlevel = settings.highlevel
    let score = settings.score
    let level = settings.level
    let lives = settings.lives
    return (level, highlevel, score, hscore, lives)
}

func saveScores(level: Int, highlevel: Int, score: Int, hscore: Int, lives: Int) {
    settings.highlevel = highlevel
    settings.score = score
    settings.level = level
    settings.highscore = hscore
    settings.lives = lives
}

func getDeviceSize() -> Double {
    // iPhone and iPad detection
    let width = UIScreen.main.bounds.size.width
    let height = UIScreen.main.bounds.size.height
    let aspect = width / height
    let ratio = round(aspect * 10) / 10
    let device = UIDevice.current.userInterfaceIdiom

    switch (ratio, device) {
    case (1.0..<2.0, .pad):
        settings.mode = 1
    case (1.5..<2.0, .phone):
        settings.mode = 2
    case (2.0..., .phone):
        settings.mode = 4
    default:
        if device == .pad {
            settings.mode = 1
        } else {
            settings.mode = 4
        }
    }
    
    return ratio
}

func setSceneSizeForGame() -> CGSize {
    let ratio = getDeviceSize()

    switch settings.mode {
    case 2:
        // regular iPhone style 1.8
        return CGSize(width: 626, height: 352)
    case 4:
        // iPhone X style 2.16
        return CGSize(width: 762, height: 352)
    default:
        // iPad (Supports ratios 1.3, 1.4, 1.5 and future 1.6)
        let x: CGFloat = round((ratio - 1.3) * 10)
        let y: CGFloat = 32 //size of the grid square (32 x 32)
        let a: CGFloat = 469 + (x * y)
        let b: CGFloat = UIScreen.main.bounds.size.width
        let c: CGFloat = UIScreen.main.bounds.size.height

        return CGSize(
            width: a,
            height: a * (min(b, c) / max(b, c))
        )
    }
}

func setSceneSizeForMenu() -> CGSize  {
    _ = getDeviceSize()
        
    //Put this in a common area
    if (settings.mode == 2 ) {
        //regular iPhone style
        return CGSize(width: 626, height: 352)
        
    } else if (settings.mode == 4) {
        // iPhone X style
        return CGSize(width: 762, height: 352)
        
    } else {
        
        let screenWidth = CGFloat(UIScreen.main.bounds.size.width)
        let screenHeight = CGFloat(UIScreen.main.bounds.size.height)
        let screenMax = CGFloat(max(screenWidth,screenHeight))
        let screenMin = CGFloat(min(screenWidth,screenHeight))
        
        return CGSize(width: 600,  height: 600 * ( screenMin / screenMax ) )
    }
}
   
typealias Oreo = (bombsbutton:SKSpriteNode?,firebutton:SKSpriteNode?,hero:SKSpriteNode?,canape:SKSpriteNode?,tractor:SKSpriteNode?,bombsbutton2:SKSpriteNode?,firebutton2:SKSpriteNode?)

func saveSettings() {
    UserDefaults.standard.setValue(settings.highlevel, forKey: "highlevel")
    UserDefaults.standard.setValue(settings.highscore, forKey: "highscore")
    UserDefaults.standard.setValue(settings.level, forKey: "level")
    UserDefaults.standard.setValue(settings.emoji, forKey: "emoji")
}

func loadSettings() {
    settings.highlevel = UserDefaults.standard.integer(forKey: "highlevel")
    settings.highscore = UserDefaults.standard.integer(forKey: "highscore")
    settings.level = UserDefaults.standard.integer(forKey: "level")
    settings.emoji = UserDefaults.standard.integer(forKey: "emoji")
    settings.level == 0 ? (settings.level+=1) : ()
    settings.level > maxlevel ? (settings.level = maxlevel) : ()
    settings.highlevel == 0 ? (settings.highlevel+=2) : ()
    settings.highlevel = 12 //MARK: ToDo Remove HighLevel
}
