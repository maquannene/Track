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
import UIKit

class MemoryObject: LRUObjectBase {
    var key: String = ""
    var value: AnyObject
    var cost: UInt = 0
    init(key: String, value: AnyObject, cost: UInt = 0) {
        self.key = key
        self.value = value
        self.cost = cost
    }
}

func == (lhs: MemoryObject, rhs: MemoryObject) -> Bool {
    return lhs.key == rhs.key
}

public typealias MemoryCacheAsyncCompletion = (cache: MemoryCache?, key: String?, object: AnyObject?) -> Void

public class MemoryCache {
    
    public var totalCount: UInt {
        get {
            lock()
            let count = _cache.count
            unlock()
            return count
        }
    }
    
    public var totalCost: UInt {
        get {
            lock()
            let cost = _cache.cost
            unlock()
            return cost
        }
    }
    
    public var countLimit: UInt {
        set {
            lock()
            _cache.countLimit = newValue
            unlock()
        }
        get {
            lock()
            let countLimit = _cache.countLimit
            unlock()
            return countLimit
        }
    }
    
    public var costLimit: UInt {
        set {
            lock()
            _cache.costLimit = newValue
            unlock()
        }
        get {
            lock()
            let costLimit = _cache.costLimit
            unlock()
            return costLimit
        }
    }
    
    private let _cache: LRU = LRU<MemoryObject>()
    
    private let _queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + String(MemoryCache), DISPATCH_QUEUE_CONCURRENT)
    
    private let _semaphoreLock: dispatch_semaphore_t = dispatch_semaphore_create(1)
    
    private var _shouldRemoveAllObjectWhenMemoryWarning: Bool
    
    //  MARK: 
    //  MARK: Public
    public static let shareInstance = MemoryCache()
    
    public init () {
        _shouldRemoveAllObjectWhenMemoryWarning = true
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MemoryCache._didReceiveMemoryWarningNotification), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }

    //  MARK: Async
    /**
     Async method to operate cache
     */
    public func set(object object: AnyObject, forKey key: String, cost: UInt = 0, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: object); return }
            strongSelf.set(object: object, forKey: key, cost: cost)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    public func object(forKey key: String, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            let object = strongSelf.object(forKey: key)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    public func removeObject(forKey key: String, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            strongSelf.removeObject(forKey: key)
            completion?(cache: strongSelf, key: key, object: nil)
        }
    }
    
    public func removeAllObject(completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.removeAllObject()
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    public func trimToCount(count: UInt, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trimToCount(count)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    public func trimToCost(cost: UInt, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trimToCost(cost)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    //  MARK: Sync
    /**
     Sync method to operate cache
     */
    public func set(object object: AnyObject, forKey key: String, cost: UInt = 0) {
        lock()
        _cache.set(object: MemoryObject(key: key, value: object, cost: cost), forKey: key)
        unlock()
    }
    
    public func object(forKey key: String) -> AnyObject? {
        var object: MemoryObject? = nil
        lock()
        object = _cache.object(forKey: key)
        unlock()
        return object?.value
    }
    
    public func removeObject(forKey key: String) {
        lock()
        _cache.removeObject(forKey:key)
        unlock()
    }
    
    public func removeAllObject() {
        lock()
        _cache.removeAllObjects()
        unlock()
    }
    
    public func trimToCount(count: UInt) {
        lock()
        _cache.trimToCount(count)
        unlock()
    }
    
    public func trimToCost(cost: UInt) {
        lock()
        _cache.trimToCost(cost)
        unlock()
    }
    
    public subscript(key: String) -> AnyObject? {
        get {
            return object(forKey: key)
        }
        set {
            if let newValue = newValue {
                set(object: newValue, forKey: key)
            } else {
                removeObject(forKey: key)
            }
        }
    }

    //  MARK:
    //  MARK: Private
    @objc private func _didReceiveMemoryWarningNotification() {
        if _shouldRemoveAllObjectWhenMemoryWarning {
            removeAllObject(nil)
        }
    }
}

//  MARK: ThreadSafeProtocol
private extension MemoryCache {
    func lock() {
        dispatch_semaphore_wait(_semaphoreLock, DISPATCH_TIME_FOREVER)
    }
    
    func unlock() {
        dispatch_semaphore_signal(_semaphoreLock)
    }
}