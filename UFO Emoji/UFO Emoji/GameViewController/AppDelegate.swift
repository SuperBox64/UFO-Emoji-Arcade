//
//  AppDelegate.swift
//  UFO Emoji
//
//  Created by Todd Bruss on 5/24/20, Updated Oct 15, 2024.
//  Copyright (c) 2026 Todd Bruss. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        loadSettings()
       
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        saveSettings()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        saveSettings()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        saveSettings()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        saveSettings()
    }


}

// MARK: - Keyboard polling compat (native Apple build ONLY)
// On the wasm builds (web wasip1 + Embedded) `SKKey` and `skKeyIsDown(_:)` come from
// SuperBox64Kit and drive GameScene.pollKeyboardInput(). The native app is touch +
// gamepad, so it reports "no key held" — this shim exists purely so the SAME,
// unconditional pollKeyboardInput() compiles on every target (no #if). This file is
// Apple-only (excluded from both wasm builds), so it never clashes with the kit's copy.
enum SKKey {
    static let a = 0, c = 2, d = 3, e = 4, f = 5, p = 15, r = 17, s = 18, v = 21, w = 22, z = 25
    static let escape = 36, space = 57, backspace = 59
    static let left = 71, right = 72, up = 73, down = 74
}
func skKeyIsDown(_ code: Int) -> Bool { false }

