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
open class CacheGenerator : IteratorProtocol {
    
    public typealias Element = (String, AnyObject)
    
    fileprivate var _memoryCacheGenerator: MemoryCacheGenerator
    
    fileprivate var _diskCacheGenerator: DiskCacheGenerator
    
    fileprivate var _memoryCache: MemoryCache
    
    fileprivate let _semaphoreLock: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    fileprivate init(memoryCacheGenerator: MemoryCacheGenerator, diskCacheGenerator: DiskCacheGenerator, memoryCache: MemoryCache) {
        self._memoryCacheGenerator = memoryCacheGenerator
        self._diskCacheGenerator = diskCacheGenerator
        self._memoryCache = memoryCache
    }
    
    /**
     Advance to the next element and return it, or `nil` if no next element exists.
     
     - returns: next element
     */
    
    open func next() -> Element? {
        if let element = _memoryCacheGenerator.next() {
            self._diskCacheGenerator.shift()
            return element
        }
        else {
            if let element: Element = _diskCacheGenerator.next() as! CacheGenerator.Element? {
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
public typealias CacheAsyncCompletion = (_ cache: Cache?, _ key: String?, _ object: Any?) -> Void

/**
 Track Cache Prefix, use on default disk cache folder name and queue name
 */
let TrackCachePrefix: String = "com.trackcache."

/**
 Track Cache default name, default disk cache folder name
 */
let TrackCacheDefauleName: String = "defaultTrackCache"

/**
 TrackCache is a thread safe cache, contain a thread safe memory cache and a thread safe diskcache.
 And support thread safe `for`...`in` loops, map, forEach...
 */
open class Cache {
    
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
    
    fileprivate let _queue: DispatchQueue = DispatchQueue(label: TrackCachePrefix + (String(describing: Cache.self)), attributes: DispatchQueue.Attributes.concurrent)
    
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
        if name.count == 0 || path.count == 0 {
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
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0])
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
    func set(object: NSCoding, forKey key: String, completion: CacheAsyncCompletion?) {
        _queue.async { [weak self] in
            guard let strongSelf = self else { completion?(nil, key, object); return }
            strongSelf.set(object: object, forKey: key)
            completion?(strongSelf, key, object)
        }
     }
    
    /**
     Async search object according to unique key
     search from memory cache first, if not found, will search from diskCache
     
     - parameter key:        object unique key
     - parameter completion: search completion call back
     */
    func object(forKey key: String, completion: CacheAsyncCompletion?) {
        _queue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.memoryCache.object(forKey: key) { [weak self] (memCache, memKey, memObject) in
                guard let strongSelf = self else { return }
                if memObject != nil {
                    strongSelf._queue.async { [weak self] in
                        completion?(self, memKey, memObject)
                    }
                }
                else {
                    strongSelf.diskCache.object(forKey: key) { [weak self] (diskCache, diskKey, diskObject) in
                        guard let strongSelf = self else { return }
                        if let diskKey = diskKey, let diskCache = diskCache {
                            strongSelf.memoryCache.set(object: diskCache, forKey: diskKey, completion: nil)
                        }
                        strongSelf._queue.async { [weak self] in
                            completion?(self, diskKey, diskObject)
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
    func removeObject(forKey key: String, completion: CacheAsyncCompletion?) {
        _queue.async { [weak self] in
            guard let strongSelf = self else { completion?(nil, key, nil); return }
            strongSelf.removeObject(forKey: key)
            completion?(strongSelf, key, nil)
        }

    }
    
    /**
     Async remove all objects
     
     - parameter completion: remove completion call back
     */
    func removeAllObjects(_ completion: CacheAsyncCompletion?) {
        _queue.async { [weak self] in
            guard let strongSelf = self else { completion?(nil, nil, nil); return }
            strongSelf.removeAllObjects()
            completion?(strongSelf, nil, nil)
        }

    }
    
    //  MARK: Sync
    /**
     Sync store an object for the unique key in the memory cache and disk cache
     
     - parameter object:     object must be implement NSCoding protocal
     - parameter key:        unique key
     - parameter completion: stroe completion call back
     */
    func set(object: NSCoding, forKey key: String) {
        memoryCache.set(object: object, forKey: key)
        diskCache.set(object: object, forKey: key)
    }
    
    /**
     Sync search an object according to unique key
     search from memory cache first, if not found, will search from diskCache
     
     - parameter key:        object unique key
     - parameter completion: search completion call back
     */
    
    func object(forKey key: String) -> AnyObject? {
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
    func removeObject(forKey key: String) {
        memoryCache.removeObject(forKey: key)
        diskCache.removeObject(forKey: key)
    }
    
    /**
     Sync remove all objects
     */
    func removeAllObjects() {
        memoryCache.removeAllObjects()
        diskCache.removeAllObjects()
    }
    
    /**
     subscript method, sync set and get
     
     - parameter key: object unique key
     */
    subscript(key: String) -> NSCoding? {
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
extension Cache : Sequence {
    /**
     CacheGenerator
     */
    public typealias Iterator = CacheGenerator
    
    /**
     Returns a generator over the elements of this sequence.
     It is thread safe, if you call `generate()`, remember release it,
     otherwise maybe it lead to deadlock.
     
     - returns: A generator
     */
    
    public func makeIterator() -> CacheGenerator {
        var generatror: CacheGenerator
        generatror = CacheGenerator(memoryCacheGenerator: memoryCache.makeIterator(), diskCacheGenerator: diskCache.makeIterator(), memoryCache: memoryCache)
        return generatror
    }
}
