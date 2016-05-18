//
//  Cache.swift
//  Demo
//
//  Created by 马权 on 5/17/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation

public typealias CacheAsyncCompletion = (cache: Cache, key: String, value: AnyObject?)

let TrackCacheDefauleName: String = "TrackCache"

public class Cache {

    public var name: String
    
    public var memoryCache: MemoryCache
    
    public var diskCache: DiskCache
    
    private let queue: dispatch_queue_t = dispatch_queue_create("com.maquan.\(TrackCacheDefauleName)", DISPATCH_QUEUE_CONCURRENT)
    
    public static let shareInstance = Cache(name: TrackCacheDefauleName)
    
    public init(name: String!, path: String!) {
        self.name = name
        self.memoryCache = MemoryCache.shareInstance
        self.diskCache = DiskCache(name: name, path: path)
    }
    
    public convenience init(name: String!) {
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
    
    //  Async
    public func set(object object: NSCoding, forKey key: String, completion: CacheAsyncCompletion?) {
        
    }
    
    public func object(forKey key: String, completion: CacheAsyncCompletion?) {
        
    }
    
    //  Sync
    public func set(object object: NSCoding!, forKey key: String!) {
        
    }
    
    public func object(forKey key: String!) -> AnyObject? {
        return nil
    }
    
}










