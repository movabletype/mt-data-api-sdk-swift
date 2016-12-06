//
//  AppDelegate.swift
//  MTDataAPI
//
//  Created by CHEEBOW on 2015/03/23.
//  Copyright (c) 2015年 Six Apart, Ltd. All rights reserved.
//

import UIKit
import SVProgressHUD
import SwiftyJSON

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var username = "username"
    var password = "password"
    var endpoint = "http://host/cgi-bin/mt/mt-data-api.cgi"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        SVProgressHUD.setBackgroundColor(UIColor.black)
        SVProgressHUD.setForegroundColor(UIColor.white)
        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.black)
        
        loadInfo()
        
        let api = DataAPI.sharedInstance
        api.APIBaseURL = "http://kujira-ongaku.net/cgi-bin/mt/mt-data-api.cgi"
        api.authentication("cheebow", password: "kotaro", remember: true,
            success:{_ in
                api.listSites(
                    success: { (result: [JSON]?, total: Int?) -> Void in
                        if let items = result {
                            print(items)
                        }
                    },
                    failure: { (error: JSON?) -> Void in
                    })
            },
            failure: { (error: JSON?) -> Void in
            }
        )
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func saveInfo() {
        let ud = UserDefaults.standard
        ud.set(self.username, forKey: "username")
        ud.set(self.password, forKey: "password")
        ud.set(self.endpoint, forKey: "endpoint")
        ud.synchronize()
    }

    func loadInfo() {
        let ud = UserDefaults.standard
        if let username = ud.string(forKey: "username") {
            self.username = username
        }
        if let password = ud.string(forKey: "password") {
            self.password = password
        }
        if let endpoint = ud.string(forKey: "endpoint") {
            self.endpoint = endpoint
        }
    }
    
}

