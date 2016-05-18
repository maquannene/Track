//
//  Cache.swift
//  Demo
//
//  Created by 马权 on 5/17/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation

public typealias CacheAsyncCompletion = (cache: Cache?, key: String?, object: AnyObject?) -> Void

let TrackCachePrefix: String = "com.trackcache."

let TrackCacheDefauleName: String = "defauleTrackCache"

public class Cache {

    public var name: String
    
    public var memoryCache: MemoryCache
    
    public var diskCache: DiskCache
    
    private let queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + (String(Cache)), DISPATCH_QUEUE_CONCURRENT)
    
    public static let shareInstance = Cache(name: TrackCacheDefauleName)
    
    public init(name: String!, path: String) {
        self.name = name
        self.memoryCache = MemoryCache.shareInstance
        self.diskCache = DiskCache(name: name, path: path)
    }
    
    public convenience init(name: String){
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
    
    //  Async
    public func set(object object: NSCoding, forKey key: String, completion: CacheAsyncCompletion?) {
        var group: dispatch_group_t? = nil
        var memorySetCompletion: MemoryCacheAsyncCompletion?
        var diskSetCompletion: DiskCacheAsyncCompletion?
        if (completion != nil) {
            group = dispatch_group_create()
            memorySetCompletion = { (_, _, _) in
                dispatch_group_leave(group!)
            }
            diskSetCompletion = { (_, _, _) in
                dispatch_group_leave(group!)
            }
        }
        
        memoryCache.set(object: object, forKey: key, completion: memorySetCompletion)
        diskCache.set(object: object, forKey: key, completion: diskSetCompletion)
        
        if (group != nil) {
            dispatch_group_notify(group!, queue) { [weak self] in
                guard let strongSelf = self else { return }
                completion?(cache: strongSelf, key: key, object: object)
            }
        }
    }
    
    public func object(forKey key: String, completion: CacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.memoryCache.object(forKey: key) { [weak self] (memCache, memKey, memObject) in
                guard let strongSelf = self else { return }
                if memObject != nil {
                    dispatch_async(strongSelf.queue, {
                        completion?(cache: strongSelf, key: memKey, object: memObject)
                    })
                }
                else {
                    strongSelf.diskCache.object(forKey: key) { [weak self] (diskCache, diskKey, diskObject) in
                        guard let strongSelf = self else { return }
                        strongSelf.memoryCache.set(object: diskCache, forKey: diskKey, completion: nil)
                        dispatch_async(strongSelf.queue, {
                            completion?(cache: strongSelf, key: diskKey, object: diskObject)
                        })
                    }
                }
            }
        }
    }
    
    public func removeObject(forKey key: String, completion: CacheAsyncCompletion?) {

    }
    
    public func removeAllObject(completion: CacheAsyncCompletion?) {

    }
    
    //  Sync
    public func set(object object: NSCoding, forKey key: String) {
        memoryCache.set(object: object, forKey: key)
        diskCache.set(object: object, forKey: key)
    }
    
    public func object(forKey key: String) -> AnyObject? {
        if let object = memoryCache.object(forKey: key) {
            return object
        }
        else {
            if let object = diskCache.object(forKey: key) {
                return object
            }
        }
        return nil
    }
    
    public func removeObject(forKey key: String) {
        memoryCache.removeObject(forKey: key)
        diskCache.removeObject(forKey: key)
    }
    
    public func removeAllObject() {
        memoryCache.removeAllObject()
        diskCache.removeAllObject()
    }
}










