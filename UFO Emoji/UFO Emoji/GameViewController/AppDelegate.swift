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

