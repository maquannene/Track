//
//  MemoryCache.swift
//  Demo
//
//  Created by 马权 on 5/17/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation

public typealias MemoryCacheAsyncCompletion = (cache: MemoryCache, key: String, value: AnyObject?)

let MemoryCacheDefauleName: String = "MemoryCacheDefaule"

public class MemoryCache {
    
    private let cahce: NSCache = NSCache()
    
    public let queue: dispatch_queue_t = dispatch_queue_create("com.maquan.\(MemoryCacheDefauleName)", DISPATCH_QUEUE_CONCURRENT)
    
    public static let shareInstance = MemoryCache()
    
    private init () {
        
    }
    
    //  Async
    public func set(object object: AnyObject, forKey key: String, completion: CacheAsyncCompletion?) {
        
    }
    
    public func object(forKey key: String, completion: CacheAsyncCompletion?) {
        
    }
    
    //  Sync
    public func set(object object: AnyObject!, forKey key: String!) {
        
    }
    
    public func object(forKey key: String!) -> AnyObject? {
        return nil
    }
    
}