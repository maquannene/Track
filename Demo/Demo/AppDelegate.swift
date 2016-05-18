//
//  AppDelegate.swift
//  Demo
//
//  Created by 马权 on 5/17/16.
//  Copyright © 2016 马权. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        let printTime: (() -> Void) -> Void = {
            let startTime: NSDate = NSDate()
            $0()
            print(startTime.timeIntervalSinceNow)
        }
        
//        var dd = [String : AnyObject]()
//        printTime {
//            for i in 0 ... 200000 {
//                dd["\(i)"] = "\(i)"
//            }
//        }
//        
//        let dic = NSMutableDictionary()
//        printTime {
//            for i in 0 ... 200000 {
//                dic["\(i)"] = "\(i)"
//            }
//        }
//        
//        printTime {
//            for i in 0 ... 200000 {
//                let x = dd["\(i)"]
//            }
//        }
//        
//        printTime {
//            for i in 0 ... 200000 {
//                let x = dic["\(i)"]
//            }
//        }
        
//        //  TM
//        let t = TMDiskCache.sharedCache()
//
//        printTime {
//            for i in 0 ... 2000 {
//                //            print(" i = \(i)")
//                t.setObject("sfdsf", forKey: "\(i)")
//            }
//        }
//        
//        //  PIN
//        let p = PINDiskCache.sharedCache()
//        
//        printTime {
//            for i in 0 ... 2000 {
//                //            print(" p = \(i)")
//                p.setObject("213", forKey: "\(i)")
//            }
//        }
        
        //  Track
        let Tr = Cache.shareInstance
        printTime {
            for i in 0 ... 5 {
                //            print(" p = \(i)")
                Tr.set(object: "213", forKey: "\(i)")
            }
        }
        
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

