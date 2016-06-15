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

import Foundation

/**
 CacheGenerator, support `for...in` loops, it is thread safe.
 */
public class CacheGenerator : GeneratorType {
    
    public typealias Element = (String, AnyObject)
    
    private var _memoryCacheGenerator: MemoryCacheGenerator
    
    private var _diskCacheGenerator: DiskCacheGenerator
    
    private var _memoryCache: MemoryCache
    
    private let _semaphoreLock: dispatch_semaphore_t = dispatch_semaphore_create(1)
    
    private init(memoryCacheGenerator: MemoryCacheGenerator, diskCacheGenerator: DiskCacheGenerator, memoryCache: MemoryCache) {
        self._memoryCacheGenerator = memoryCacheGenerator
        self._diskCacheGenerator = diskCacheGenerator
        self._memoryCache = memoryCache
    }
    
    /**
     Advance to the next element and return it, or `nil` if no next element exists.
     
     - returns: next element
     */
    @warn_unused_result
    public func next() -> Element? {
        if let element = _memoryCacheGenerator.next() {
            self._diskCacheGenerator.shift()
            return element
        }
        else {
            if let element: Element = _diskCacheGenerator.next() {
                _memoryCache._unsafeSet(object: element.1, forKey: element.0)
                return element
            }
        }
        return nil
    }
}

/**
 Cache async operation callback
 */
public typealias CacheAsyncCompletion = (cache: Cache?, key: String?, object: AnyObject?) -> Void

/**
 Track Cache Prefix, use on default disk cache folder name and queue name
 */
let TrackCachePrefix: String = "com.trackcache."

/**
 Track Cache default name, default disk cache folder name
 */
let TrackCacheDefauleName: String = "defauleTrackCache"

/**
 TrackCache is a thread safe cache, contain a thread safe memory cache and a thread safe diskcache.
 And support thread safe `for`...`in` loops, map, forEach...
 */
public class Cache {
    
    /**
     cache name, used to create disk cache folder
     */
    public let name: String
    
    /**
     Thread safe memeory cache
     */
    public let memoryCache: MemoryCache
    
    /**
     Thread safe disk cache
     */
    public let diskCache: DiskCache
    
    private let _queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + (String(Cache)), DISPATCH_QUEUE_CONCURRENT)
    
    /**
     A share cache, contain a thread safe memory cache and a thread safe diskcache
     */
    public static let shareInstance = Cache(name: TrackCacheDefauleName)!
    
    /**
     Design constructor
     The same name has the same diskCache, but different memorycache.
     
     - parameter name: cache name
     - parameter path: diskcache path
     */
    public init?(name: String, path: String) {
        if name.characters.count == 0 || path.characters.count == 0 {
            return nil
        }
        self.diskCache = DiskCache(name: name, path: path)!
        self.name = name
        self.memoryCache = MemoryCache.shareInstance
    }
    
    /**
     Convenience constructor, use default path Library/Caches/
     
     - parameter name: cache name
     */
    public convenience init?(name: String){
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
}

//  MARK:
//  MARK: Public
public extension Cache {
    //  MARK: Async
    /**
     Async store an object for the unique key in the memory cache and disk cache
     completion will be call after object has been store in memory cache and disk cache
     
     - parameter object:     object must be implement NSCoding protocal
     - parameter key:        unique key
     - parameter completion: stroe completion call back
     */
    public func set(object object: NSCoding, forKey key: String, completion: CacheAsyncCompletion?) {
        _asyncGroup(2, operation: { completion in
            self.memoryCache.set(object: object, forKey: key) { _, _, _ in completion?() }
            self.diskCache.set(object: object, forKey: key) { _, _, _ in completion?() }
        }, notifyQueue: _queue) { [weak self] in
            completion?(cache: self, key: key, object: object)
        }
    }
    
    /**
     Async search object according to unique key
     search from memory cache first, if not found, will search from diskCache
     
     - parameter key:        object unique key
     - parameter completion: search completion call back
     */
    public func object(forKey key: String, completion: CacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.memoryCache.object(forKey: key) { [weak self] (memCache, memKey, memObject) in
                guard let strongSelf = self else { return }
                if memObject != nil {
                    dispatch_async(strongSelf._queue) { [weak self] in
                        completion?(cache: self, key: memKey, object: memObject)
                    }
                }
                else {
                    strongSelf.diskCache.object(forKey: key) { [weak self] (diskCache, diskKey, diskObject) in
                        guard let strongSelf = self else { return }
                        if let diskKey = diskKey, diskCache = diskCache {
                            strongSelf.memoryCache.set(object: diskCache, forKey: diskKey, completion: nil)
                        }
                        dispatch_async(strongSelf._queue) { [weak self] in
                            completion?(cache: self, key: diskKey, object: diskObject)
                        }
                    }
                }
            }
        }
    }
    
    /**
     Async remove object from memory cache and disk cache
     
     - parameter key:        object unique key
     - parameter completion: remove completion call back
     */
    public func removeObject(forKey key: String, completion: CacheAsyncCompletion?) {
        _asyncGroup(2, operation: { completion in
            self.memoryCache.removeObject(forKey: key) { _, _, _ in completion?() }
            self.diskCache.removeObject(forKey: key) { _, _, _ in completion?() }
        }, notifyQueue: _queue) { [weak self] in
            completion?(cache: self, key: key, object: nil)
        }
    }
    
    /**
     Async remove all objects
     
     - parameter completion: remove completion call back
     */
    public func removeAllObjects(completion: CacheAsyncCompletion?) {
        _asyncGroup(2, operation: { completion in
            self.memoryCache.removeAllObjects { _, _, _ in completion?() }
            self.diskCache.removeAllObjects { _, _, _ in completion?() }
        }, notifyQueue: _queue) { [weak self] in
            completion?(cache: self, key: nil, object: nil)
        }
    }
    
    //  MARK: Sync
    /**
     Sync store an object for the unique key in the memory cache and disk cache
     
     - parameter object:     object must be implement NSCoding protocal
     - parameter key:        unique key
     - parameter completion: stroe completion call back
     */
    public func set(object object: NSCoding, forKey key: String) {
        memoryCache.set(object: object, forKey: key)
        diskCache.set(object: object, forKey: key)
    }
    
    /**
     Sync search an object according to unique key
     search from memory cache first, if not found, will search from diskCache
     
     - parameter key:        object unique key
     - parameter completion: search completion call back
     */
    @warn_unused_result
    public func object(forKey key: String) -> AnyObject? {
        if let object = memoryCache.object(forKey: key) {
            return object
        }
        else {
            if let object = diskCache.object(forKey: key) {
                memoryCache.set(object: object, forKey: key)
                return object
            }
        }
        return nil
    }
    
    /**
     Sync remove object from memory cache and disk cache
     
     - parameter key:        object unique key
     */
    public func removeObject(forKey key: String) {
        memoryCache.removeObject(forKey: key)
        diskCache.removeObject(forKey: key)
    }
    
    /**
     Sync remove all objects
     */
    public func removeAllObjects() {
        memoryCache.removeAllObjects()
        diskCache.removeAllObjects()
    }
    
    /**
     subscript method, sync set and get
     
     - parameter key: object unique key
     */
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
}

//  MARK: SequenceType
extension Cache : SequenceType {
    /**
     CacheGenerator
     */
    public typealias Generator = CacheGenerator
    
    /**
     Returns a generator over the elements of this sequence.
     It is thread safe, if you call `generate()`, remember release it,
     otherwise maybe it lead to deadlock.
     
     - returns: A generator
     */
    @warn_unused_result
    public func generate() -> CacheGenerator {
        var generatror: CacheGenerator
        generatror = CacheGenerator(memoryCacheGenerator: memoryCache.generate(), diskCacheGenerator: diskCache.generate(), memoryCache: memoryCache)
        return generatror
    }
}

//  MARK:
//  MARK: Pirvate
private extension Cache {
    
    private typealias OperationCompeltion = () -> Void
    
    private func _asyncGroup(asyncNumber: Int,
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
