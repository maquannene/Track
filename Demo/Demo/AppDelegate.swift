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
            let startTime: CFTimeInterval = CACurrentMediaTime()
            $0()
            let endTime: CFTimeInterval = CACurrentMediaTime()
            print((endTime - startTime) * 1000)
        }
        
        let time: UInt = 5
        
        //        let dd = NSMutableDictionary()
        //        printTime {
        //            for i in 0 ... time {
        //                dd["\(i * 2)"] = "\(i)"
        //            }
        //        }
        //
        //        printTime {
        //            for i in 0 ... time {
        //                if i % 2 == 0 {
        //                    let x = dd["\(i)"]
        //                }
        //            }
        //        }
        //
        //        printTime {
        //            for i in 0 ... time0 {
        //                let x = dd["\(i)"]
        //            }
        //        }
        //
        //        printTime {
        //            for i in 0 ... time0 {
        //                let x = dic["\(i)"]
        //            }
        //        }
        
        //  TM
        //        let t = TMMemoryCache.sharedCache()
        //
        //        printTime {
        //            for i in 0 ... time {
        //                //            print(" i = \(i)")
        //                t.setObject("sfdsf", forKey: "\(i)")
        //            }
        //        }
        //
        //        printTime {
        //            for i in 0 ... time {
        //                if i % 2 == 0 {
        //                    t.objectForKey("\(i)")
        //                }
        //            }
        //        }
        
        //        //  PIN
        //        let p = PINMemoryCache.sharedCache()
        //
        //        printTime {
        //            for i in 0 ... time {
        //                //            print(" p = \(i)")
        //                p.setObject("\(i * 2)", forKey: "\(i)")
        //            }
        //        }
        //
        //        printTime {
        //            for i in 0 ... time {
        //                if i % 2 == 0 {
        //                    p.objectForKey("\(i)")
        //                }
        //            }
        //        }
        
        //        //  YY
        //        let yy = YYMemoryCache()
        //
        //        printTime {
        //            for i in 0 ... time {
        //                yy.setObject("\(i * 2)", forKey: "\(i)")
        //            }
        //        }
        //
        //        printTime {
        //            for i in 0 ... time {
        //                if i % 2 == 0 {
        //                    yy.objectForKey("\(i)")
        //                }
        //            }
        //        }
        //
        
//          Track
        let cache: MemoryCache = MemoryCache.shareInstance

//        printTime {
//            for i in 0 ... time {
//                cache.set(object: "\(i)", forKey: "\(i)")
//            }
//        }
//        
//        printTime {
//            for i in 0 ... time {
//                if i < 3 {
//                    cache.removeObject(forKey: "\(i)")
//                }
//            }
//        }
    
        for i in 1 ... 10000 {
            cache.set(object: "\(i)", forKey: "\(i)")
        }

        cache.trim(toCount: 5)
        
        for object in cache {
            print(object)
        }
        
        cache.object(forKey: "\(1)", completion: { (cache, key, object) in
            
        })
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

