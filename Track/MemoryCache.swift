//The MIT License (MIT)
//
//Copyright (c) 2016 U Are My SunShine
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

/**
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

private class MemoryCacheObject: LRUObjectBase {
    var key: String = ""
    var cost: UInt = 0
    var time: NSTimeInterval = CACurrentMediaTime()
    var value: AnyObject
    init(key: String, value: AnyObject, cost: UInt = 0) {
        self.key = key
        self.value = value
        self.cost = cost
    }
}

private func == (lhs: MemoryCacheObject, rhs: MemoryCacheObject) -> Bool {
    return lhs.key == rhs.key
}

public typealias MemoryCacheAsyncCompletion = (cache: MemoryCache?, key: String?, object: AnyObject?) -> Void

/**
 MemoryCache is a thread safe cache implement by dispatch_semaphore_t lock and DISPATCH_QUEUE_CONCURRENT
 Cache algorithms policy use LRU (Least Recently Used) implement by linked list and cache in NSDictionary
 so the cache support eliminate least recently used object according count limit, cost limit and age limit
 */
public class MemoryCache {
    
    /**
     Disk cache object total count
     */
    public var totalCount: UInt {
        get {
            lock()
            let count = _cache.count
            unlock()
            return count
        }
    }
    
    /**
     Disk cache object total cost, if not set cost when set object, total cost may be zero
     */
    public var totalCost: UInt {
        get {
            lock()
            let cost = _cache.cost
            unlock()
            return cost
        }
    }
    
    private var _countLimit: UInt = UInt.max
    
    /**
     The maximum total count limit
     */
    public var countLimit: UInt {
        set {
            lock()
            _countLimit = newValue
            _unsafeTrimToCount(newValue)
            unlock()
        }
        get {
            lock()
            let countLimit = _countLimit
            unlock()
            return countLimit
        }
    }
    
    private var _costLimit: UInt = UInt.max
    
    /**
     The maximum disk cost limit
     */
    public var costLimit: UInt {
        set {
            lock()
            _costLimit = newValue
            _unsafeTrimToCost(newValue)
            unlock()
        }
        get {
            lock()
            let costLimit = _costLimit
            unlock()
            return costLimit
        }
    }
    
    private var _ageLimit: NSTimeInterval = DBL_MAX
    
    /**
     Disk cache object age limit
     */
    public var ageLimit: NSTimeInterval {
        set {
            lock()
            _ageLimit = newValue
            _unsafeTrimToAge(newValue)
            unlock()
        }
        get {
            lock()
            let ageLimit = _ageLimit
            unlock()
            return ageLimit
        }
    }
    
    private let _cache: LRU = LRU<MemoryCacheObject>()
    
    private let _queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + String(MemoryCache), DISPATCH_QUEUE_CONCURRENT)
    
    private let _semaphoreLock: dispatch_semaphore_t = dispatch_semaphore_create(1)
    
    private var _shouldRemoveAllObjectWhenMemoryWarning: Bool
    
    /**
     A share memory cache
     */
    public static let shareInstance = MemoryCache()
    
    /**
     Design constructor
     */
    public init () {
        _shouldRemoveAllObjectWhenMemoryWarning = true
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MemoryCache._didReceiveMemoryWarningNotification), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
}

//  MARK:
//  MARK: Public
public extension MemoryCache {
    
    //  MARK: Async
    /**
     Async store an object for the unique key in memory cache and add object to linked list head
     completion will be call after object has been store in disk
     
     - parameter object:     object
     - parameter key:        unique key
     - parameter completion: stroe completion call back
     */
    public func set(object object: AnyObject, forKey key: String, cost: UInt = 0, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: object); return }
            strongSelf.set(object: object, forKey: key, cost: cost)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    /**
     Async search object according to unique key
     if find object, object will move to linked list head
     */
    public func object(forKey key: String, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            let object = strongSelf.object(forKey: key)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    /**
     Async remove object according to unique key from cache dic and linked list
     */
    public func removeObject(forKey key: String, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            strongSelf.removeObject(forKey: key)
            completion?(cache: strongSelf, key: key, object: nil)
        }
    }
    
    /**
     Async remove all object and info from cache dic and clean linked list
     */
    public func removeAllObjects(completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.removeAllObjects()
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    /**
     Async trim disk cache total to countLimit according LRU
     
     - parameter countLimit: maximum countLimit
     */
    public func trimToCount(countLimit: UInt, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trimToCount(countLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    /**
     Async trim disk cache totalcost to costLimit according LRU
     
     - parameter costLimit:  maximum costLimit
     */
    public func trimToCost(costLimit: UInt, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trimToCost(costLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    /**
     Async trim disk cache objects which age greater than ageLimit
     
     - parameter costLimit:  maximum costLimit
     */
    public func trimToAge(ageLimit: NSTimeInterval, completion: MemoryCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trimToAge(ageLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    //  MARK: Sync
    /**
     Sync store an object for the unique key in memory cache and add object to linked list head
     */
    public func set(object object: AnyObject, forKey key: String, cost: UInt = 0) {
        lock()
        _cache.set(object: MemoryCacheObject(key: key, value: object, cost: cost), forKey: key)
        if _cache.cost > _costLimit {
            _unsafeTrimToCost(_costLimit)
        }
        if _cache.count > _countLimit {
            _unsafeTrimToCount(_countLimit)
        }
        unlock()
    }
    
    /**
     Async search object according to unique key
     if find object, object will move to linked list head
     */
    public func object(forKey key: String) -> AnyObject? {
        var object: MemoryCacheObject? = nil
        lock()
        object = _cache.object(forKey: key)
        object?.time = CACurrentMediaTime()
        unlock()
        return object?.value
    }
    
    /**
     Sync remove object according to unique key from cache dic and linked list
     */
    public func removeObject(forKey key: String) {
        lock()
        _cache.removeObject(forKey:key)
        unlock()
    }
    
    /**
     Sync remove all object and info from cache dic and clean linked list
     */
    public func removeAllObjects() {
        lock()
        _cache.removeAllObjects()
        unlock()
    }
    
    /**
     Sync trim disk cache totalcost to costLimit according LRU
     */
    public func trimToCount(countLimit: UInt) {
        lock()
        _unsafeTrimToCount(countLimit)
        unlock()
    }
    
    /**
     Sync trim disk cache totalcost to costLimit according LRU
     */
    public func trimToCost(costLimit: UInt) {
        lock()
        _unsafeTrimToCost(costLimit)
        unlock()
    }
    
    /**
     Sync trim disk cache objects which age greater than ageLimit
     
     - parameter costLimit:  maximum costLimit
     */
    public func trimToAge(ageLimit: NSTimeInterval) {
        lock()
        _unsafeTrimToAge(ageLimit)
        unlock()
    }
    
    /**
     subscript method, sync set and get
     
     - parameter key: object unique key
     */
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
}

//  MARK:
//  MARK: Private
private extension MemoryCache {
    
    @objc private func _didReceiveMemoryWarningNotification() {
        if _shouldRemoveAllObjectWhenMemoryWarning {
            removeAllObjects(nil)
        }
    }
    
    private func _unsafeTrimToCount(countLimit: UInt) {
        if _cache.count <= countLimit {
            return
        }
        if countLimit == 0 {
            _cache.removeAllObjects()
            return
        }
        if var _: MemoryCacheObject = _cache.lastObject() {
            while (_cache.count > countLimit) {
                _cache.removeLastObject()
                guard let _: MemoryCacheObject = _cache.lastObject() else { return }
            }
        }
    }
    
    private func _unsafeTrimToCost(costLimit: UInt) {
        if _cache.cost <= costLimit {
            return
        }
        if costLimit == 0 {
            _cache.removeAllObjects()
            return
        }
        if var _: MemoryCacheObject = _cache.lastObject() {
            while (_cache.cost > costLimit) {
                _cache.removeLastObject()
                guard let _: MemoryCacheObject = _cache.lastObject() else { return }
            }
        }
    }
    
    private func _unsafeTrimToAge(ageLimit: NSTimeInterval) {
        if ageLimit <= 0 {
            _cache.removeAllObjects()
            return
        }
        if var lastObject: MemoryCacheObject = _cache.lastObject() {
            while (CACurrentMediaTime() - lastObject.time > ageLimit) {
                _cache.removeLastObject()
                guard let newLastObject: MemoryCacheObject = _cache.lastObject() else { return }
                lastObject = newLastObject
            }
        }
    }
    
    func lock() {
        dispatch_semaphore_wait(_semaphoreLock, DISPATCH_TIME_FOREVER)
    }
    
    func unlock() {
        dispatch_semaphore_signal(_semaphoreLock)
    }
}