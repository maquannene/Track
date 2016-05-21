//
//  Cache.swift
//  Demo
//
//  Created by 马权 on 5/17/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation

public typealias CacheAsyncCompletion = (cache: Cache?, key: String?, object: AnyObject?) -> Void

public let TrackCachePrefix: String = "com.trackcache."

public let TrackCacheDefauleName: String = "defauleTrackCache"

public class Cache {
    
    public let name: String
    
    public let memoryCache: MemoryCache
    
    public let diskCache: DiskCache
    
    private let _queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + (String(Cache)), DISPATCH_QUEUE_CONCURRENT)
    
    //  MARK:
    //  MARK: Public
    public static let shareInstance = Cache(name: TrackCacheDefauleName)
    
    public init?(name: String, path: String) {
        if name.characters.count == 0 || path.characters.count == 0 {
            return nil
        }
        self.diskCache = DiskCache(name: name, path: path)!
        self.name = name
        self.memoryCache = MemoryCache.shareInstance
    }
    
    public convenience init?(name: String){
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
    
    //  MARK: Async
    public func set(object object: NSCoding, forKey key: String, completion: CacheAsyncCompletion?) {
        asyncGroup(2, operation: { completion in
            self.memoryCache.set(object: object, forKey: key) { _, _, _ in completion?() }
            self.diskCache.set(object: object, forKey: key) { _, _, _ in completion?() }
        }, notifyQueue: _queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    public func object(forKey key: String, completion: CacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.memoryCache.object(forKey: key) { [weak self] (memCache, memKey, memObject) in
                guard let strongSelf = self else { return }
                if memObject != nil {
                    dispatch_async(strongSelf._queue, {
                        completion?(cache: strongSelf, key: memKey, object: memObject)
                    })
                }
                else {
                    strongSelf.diskCache.object(forKey: key) { [weak self] (diskCache, diskKey, diskObject) in
                        guard let strongSelf = self else { return }
                        if let diskKey = diskKey, diskCache = diskCache {
                            strongSelf.memoryCache.set(object: diskCache, forKey: diskKey, completion: nil)
                        }
                        dispatch_async(strongSelf._queue, {
                            completion?(cache: strongSelf, key: diskKey, object: diskObject)
                        })
                    }
                }
            }
        }
    }
    
    public func removeObject(forKey key: String, completion: CacheAsyncCompletion?) {
        asyncGroup(2, operation: { completion in
            self.memoryCache.removeObject(forKey: key) { _, _, _ in completion?() }
            self.diskCache.removeObject(forKey: key) { _, _, _ in completion?() }
        }, notifyQueue: _queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    public func removeAllObject(completion: CacheAsyncCompletion?) {
        asyncGroup(2, operation: { completion in
            self.memoryCache.removeAllObject { _, _, _ in completion?() }
            self.diskCache.removeAllObject { _, _, _ in completion?() }
        }, notifyQueue: _queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    //  MARK: Sync
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
    
    public subscript(key: String) -> NSCoding? {
        get {
            if let returnValue = object(forKey: key) as? NSCoding {
                return returnValue
            }
            return nil
        }
        set {
            if let newValue = newValue {
                set(object: newValue, forKey: key)
            }
            else {
                removeObject(forKey: key)
            }
        }
    }
    
    //  MARK:
    //  MARK: Pirvate
    
    private typealias OperationCompeltion = () -> Void
    
    private func asyncGroup(asyncNumber: Int,
                            operation: OperationCompeltion? -> Void,
                            notifyQueue: dispatch_queue_t,
                            completion: (() -> Void)?) {
        var group: dispatch_group_t? = nil
        var operationCompletion: OperationCompeltion?
        if (completion != nil) {
            group = dispatch_group_create()
            for _ in 0 ..< asyncNumber {
                group = dispatch_group_create()
            }
            operationCompletion = {
                dispatch_group_leave(group!)
            }
        }
        
        operation(operationCompletion)
        
        if let group = group {
            dispatch_group_notify(group, _queue) {
                completion?()
            }
        }
    }
}




