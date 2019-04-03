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
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let printTime: (() -> Void) -> Void = {
            let startTime: CFTimeInterval = CACurrentMediaTime()
            $0()
            let endTime: CFTimeInterval = CACurrentMediaTime()
            print((endTime - startTime) * 1000)
        }
        
        let time: UInt = 5
        
        //          Track
        let cache: Cache = Cache.shareInstance
        
        //        for i in 1 ... 5 {
        //            cache.set(object: "\(i)", forKey: "\(i)")
        //        }
        //
        for i in 6 ... 7 {
            cache.set(object: "\(i)" as NSCoding, forKey: "\(i)")
        }
        
        for object in cache {
            print(object)
        }
        
        cache.forEach {
            print($0)
        }
        
        let values = cache.map { return $0 }
        
        print(values)
        
        return true
    }
    
    
}

