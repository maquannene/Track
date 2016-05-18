//
//  MemoryCache.swift
//  Demo
//
//  Created by 马权 on 5/17/16.
//  Copyright © 2016 马权. All rights reserved.
//

/*
    MemoryCache
 
    thread safe = concurrent + semaphore lock
 
    sync
    thread safe write = write + semaphore lock
    thread safe read = read + semaphore lokc
    
    async
    thread safe write = async concurrent queue + thread safe sync write
    thread safe read = async concurrent queue + thread safe sync read
 
 */

import Foundation

public typealias MemoryCacheAsyncCompletion = (cache: MemoryCache?, key: String, object: AnyObject?) -> Void

public class MemoryCache {
    
    private var cache: Dictionary = [String : AnyObject]()
    
    private let queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + String(MemoryCache), DISPATCH_QUEUE_CONCURRENT)
    
    private let semaphoreLock: dispatch_semaphore_t = dispatch_semaphore_create(1)
    
    public static let shareInstance = MemoryCache()
    
    init () {
        
    }
    
    //  Async
    public func set(object object: AnyObject!, forKey key: String!, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let sSelf = self else { completion?(cache: nil, key: key, object: object); return }
            sSelf.set(object: object, forKey: key)
            completion?(cache: sSelf, key: key, object: object)
        }
    }
    
    public func object(forKey key: String, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let sSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            let object = sSelf.object(forKey: key)
            completion?(cache: sSelf, key: key, object: object)
        }
    }
    
    //  Sync
    public func set(object object: AnyObject, forKey key: String) {
        lock()
        cache[key] = object
        unlock()
    }
    
    public func object(forKey key: String) -> AnyObject? {
        lock()
        let object: AnyObject? = cache[key]
        unlock()
        return object
    }
    
    private func lock() {
        dispatch_semaphore_wait(semaphoreLock, DISPATCH_TIME_FOREVER)
    }
    
    private func unlock() {
        dispatch_semaphore_signal(semaphoreLock)
    }
}