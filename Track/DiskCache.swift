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
 DiskCache
 
 thread safe = concurrent + semaphore lock
 
 sync
 thread safe write = write + semaphore lock
 thread safe read = read + semaphore lokc
 
 async
 thread safe write = async concurrent queue + thread safe sync write
 thread safe read = async concurrent queue + thread safe sync read
 */

import Foundation
import QuartzCore

/**
 *  FastGeneratorType, inherit GeneratorType and provide a method to shift offset.
 */
public protocol FastGeneratorType: GeneratorType {
    
    /**
     Shift like next, but there is no return value.
     If you just shift offset, it`s implementation should fast than `next()`
     */
    func shift()
}

/**
 DiskCacheGenerator, support `for...in` `map` `forEach`..., it is thread safe.
 */
public class DiskCacheGenerator : FastGeneratorType {
    
    public typealias Element = (String, AnyObject)
    
    private var _lruGenerator: LRUGenerator<DiskCacheObject>
    
    private var _diskCache: DiskCache
    
    private var _completion: (() -> Void)?
    
    private init(generate: LRUGenerator<DiskCacheObject>, diskCache: DiskCache, completion: (() -> Void)?) {
        self._lruGenerator = generate
        self._diskCache = diskCache
        self._completion = completion
    }
    
    /**
     Advance to the next element and return it, or `nil` if no next element exists.
     
     - returns: next element
     */
    @warn_unused_result
    public func next() -> Element? {
        if let key = _lruGenerator.next()?.key {
            if  let value = _diskCache._unsafeObject(forKey: key) {
                return (key, value)
            }
        }
        return nil
    }
    
    /**
     Shift like next, but there is no return value and shift fast.
     */
    public func shift() {
        let _ = _lruGenerator.shift()
    }
    
    deinit {
        _completion?()
    }
}

private class DiskCacheObject: LRUObject {
    
    var key: String = ""
    var cost: UInt = 0
    var date: NSDate = NSDate()
    
    init (key: String, cost: UInt = 0, date: NSDate) {
        self.key = key
        self.cost = cost
        self.date = date
    }
    
    convenience init (key: String, cost: UInt = 0) {
        self.init(key: key, cost: cost, date: NSDate())
    }
}

public typealias DiskCacheAsyncCompletion = (cache: DiskCache?, key: String?, object: AnyObject?) -> Void

/**
 DiskCache is a thread safe cache implement by dispatch_semaphore_t lock and DISPATCH_QUEUE_CONCURRENT
 Cache algorithms policy use LRU (Least Recently Used) implement by linked list.
 You can manage cache through functions to limit size, age of entries and memory usage to eliminate least recently used object.
 And support thread safe `for`...`in` loops, map, forEach...
 */
public class DiskCache {
    
    /**
     DiskCache folder name
     */
    public let name: String
    
    /**
     DiskCache folder path URL
     */
    public let cacheURL: NSURL
    
    /**
     Disk cache object total count
     */
    public var totalCount: UInt {
        get {
            _lock()
            let count = _cache.count
            _unlock()
            return count
        }
    }
    
    /**
     Disk cache object total cost (byte)
     */
    public var totalCost: UInt {
        get {
            _lock()
            let cost = _cache.cost
            _unlock()
            return cost
        }
    }
    
    private var _countLimit: UInt = UInt.max
    
    /**
     The maximum total quantity
     */
    public var countLimit: UInt {
        set {
            _lock()
            _countLimit = newValue
            _unlock()
            trim(toCount: newValue)
        }
        get {
            _lock()
            let countLimit = _countLimit
            _unlock()
            return countLimit
        }
    }
    
    private var _costLimit: UInt = UInt.max
    
    /**
     The maximum disk cost limit
     */
    public var costLimit: UInt {
        set {
            _lock()
            _costLimit = newValue
            _unlock()
            trim(toCost: newValue)
        }
        get {
            _lock()
            let costLimit = _costLimit
            _unlock()
            return costLimit
        }
    }
    
    private var _ageLimit: NSTimeInterval = DBL_MAX
    
    /**
     Disk cache object age limit
     */
    public var ageLimit: NSTimeInterval {
        set {
            _lock()
            _ageLimit = newValue
            _unlock()
            trim(toAge: newValue)
        }
        get {
            _lock()
            let ageLimit = _ageLimit
            _unlock()
            return ageLimit
        }
    }
    
    private let _cache: LRU = LRU<DiskCacheObject>()
    
    private let _queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + (String(DiskCache)), DISPATCH_QUEUE_CONCURRENT)
    
    private let _semaphoreLock: dispatch_semaphore_t = dispatch_semaphore_create(1)
    
    /**
     A share disk cache, name "defauleTrackCache" path "Library/Caches/"
     */
    public static let shareInstance = DiskCache(name: TrackCacheDefauleName)!
    
    /**
     Design constructor
     The same name and path has the same disk folder Cache
     
     - parameter name: disk cache folder name
     - parameter path: disk cache folder path
     
     - returns: if no name or path will be fail
     */
    public init?(name: String, path: String) {
        if name.characters.count == 0 || path.characters.count == 0 {
            return nil
        }
        self.name = name
        self.cacheURL = NSURL(string: path)!.URLByAppendingPathComponent(TrackCachePrefix + name, isDirectory: false)
        
        _lock()
        dispatch_async(_queue) {
            self._createCacheDir()
            self._loadFilesInfo()
            self._unlock()
        }
    }
    
    /**
     convenience constructor
     
     - parameter name: disk cache foler name
     
     - returns: if no name will be fail
     */
    public convenience init?(name: String) {
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
}

//  MARK:
//  MARK: Public 
public extension DiskCache {
    //  MARK: Async
    /**
     Async store an object for the unique key in disk cache and store object info to linked list head
     completion will be call after object has been store in disk
     
     - parameter object:     object must be implement NSCoding protocal
     - parameter key:        unique key
     - parameter completion: stroe completion call back
     */
    public func set(object object: NSCoding, forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: object); return }
            strongSelf.set(object: object, forKey: key)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    /**
     Async search object according to unique key
     if find object, object info will move to linked list head
     */
    public func object(forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            let object = strongSelf.object(forKey: key)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    /**
     Async remove object according to unique key from disk and remove object info from linked list
     */
    public func removeObject(forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            strongSelf.removeObject(forKey: key)
            completion?(cache: strongSelf, key: key, object: nil)
        }
    }
    
    /**
     Async remove all object and info from disk and linked list
     */
    public func removeAllObjects(completion: DiskCacheAsyncCompletion?) {
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
    public func trim(toCount countLimit: UInt, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trim(toCount: countLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    /**
     Async trim disk cache totalcost to costLimit according LRU
     
     - parameter costLimit:  maximum costLimit
     */
    public func trim(toCost costLimit: UInt, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trim(toCost: costLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    /**
     Async trim disk cache objects which age greater than ageLimit
     
     - parameter costLimit:  maximum costLimit
     */
    public func trim(toAge ageLimit: NSTimeInterval, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trim(toAge: ageLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    //  MARK: Sync
    /**
     Sync store an object for the unique key in disk cache and store object info to linked list head
     */
    public func set(object object: NSCoding, forKey key: String) {
        let fileURL = _generateFileURL(key, path: cacheURL)
        _lock()
        
        if NSKeyedArchiver.archiveRootObject(object, toFile: fileURL.absoluteString) == true {
            do {
                let date: NSDate = NSDate()
                try NSFileManager.defaultManager().setAttributes([NSFileModificationDate : date], ofItemAtPath: fileURL.path!)
                let infosDic: [String : AnyObject] = try NSURL(fileURLWithPath: fileURL.absoluteString).resourceValuesForKeys([NSURLTotalFileAllocatedSizeKey])
                var fileSize: UInt = 0
                if let fileSizeNumber = infosDic[NSURLTotalFileAllocatedSizeKey] as? NSNumber {
                    fileSize = fileSizeNumber.unsignedLongValue
                }
                _cache.set(object: DiskCacheObject(key: key, cost: fileSize, date: date), forKey: key)
            } catch {}
        }
        if _cache.cost > _costLimit {
            _unsafeTrim(toCost: _costLimit)
        }
        if _cache.count > _countLimit {
            _unsafeTrim(toCount: _countLimit)
        }
        _unlock()
    }
    
    /**
     Sync search object according to unique key
     if find object, object info will move to linked list head
     */
    @warn_unused_result
    public func object(forKey key: String) -> AnyObject? {
        _lock()
        let object = _unsafeObject(forKey: key)
        _unlock()
        return object
    }
    
    /**
     Sync remove object according to unique key from disk and remove object info from linked list
     */
    public func removeObject(forKey key: String) {
        let fileURL = _generateFileURL(key, path: cacheURL)
        _lock()
        if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(fileURL.absoluteString)
                _cache.removeObject(forKey: key)
            } catch {}
        }
        _unlock()
    }
    
    /**
     Sync remove all object and info from disk and linked list
     */
    public func removeAllObjects() {
        _lock()
        if NSFileManager.defaultManager().fileExistsAtPath(self.cacheURL.absoluteString) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(self.cacheURL.absoluteString)
                _cache.removeAllObjects()
            } catch {}
        }
        _unlock()
    }
    
    /**
     Async trim disk cache total to countLimit according LRU
     */
    public func trim(toCount countLimit: UInt) {
        if self.totalCount <= countLimit {
            return
        }
        if countLimit == 0 {
            removeAllObjects()
            return
        }
        _lock()
        _unsafeTrim(toCount: countLimit)
        _unlock()
    }
    
    /**
     Sync trim disk cache totalcost to costLimit according LRU
     */
    public func trim(toCost costLimit: UInt) {
        if self.totalCost <= costLimit {
            return
        }
        if costLimit == 0 {
            removeAllObjects()
            return
        }
        _lock()
        _unsafeTrim(toCost: costLimit)
        _unlock()
    }
    
    /**
     Sync trim disk cache objects which age greater than ageLimit
     */
    public func trim(toAge ageLimit: NSTimeInterval) {
        if ageLimit <= 0 {
            removeAllObjects()
            return
        }
        _lock()
        _unsafeTrim(toAge: ageLimit)
        _unlock()
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
}

//  MARK: SequenceType
extension DiskCache : SequenceType {
    /**
     MemoryCacheGenerator
     */
    public typealias Generator = DiskCacheGenerator
    
    /**
     Returns a generator over the elements of this sequence.
     It is thread safe, if you call `generate()`, remember release it,
     otherwise maybe it lead to deadlock.
     
     - returns: A generator
     */
    @warn_unused_result
    public func generate() -> DiskCacheGenerator {
        var generatror: DiskCacheGenerator
        _lock()
        generatror = DiskCacheGenerator(generate: _cache.generate(), diskCache: self) {
            self._unlock()
        }
        return generatror
    }
}

//  MARK:
//  MARK: Private
private extension DiskCache {

    private func _createCacheDir() -> Bool {
        if NSFileManager.defaultManager().fileExistsAtPath(cacheURL.absoluteString) {
            return false
        }
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(cacheURL.absoluteString, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return false
        }
        return true
    }
    
    private func _loadFilesInfo() -> Bool {
        var fileInfos: [DiskCacheObject] = [DiskCacheObject]()
        let fileInfoKeys: [String] = [NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey]
        
        do {
            let filesURL: [NSURL] = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(cacheURL, includingPropertiesForKeys: fileInfoKeys, options: .SkipsHiddenFiles)
            for fileURL: NSURL in filesURL {
                do {
                    let infosDic: [String : AnyObject] = try fileURL.resourceValuesForKeys(fileInfoKeys)
                    
                    if let key = fileURL.lastPathComponent as String?,
                        date = infosDic[NSURLContentModificationDateKey] as? NSDate,
                        fileSize = infosDic[NSURLTotalFileAllocatedSizeKey] as? NSNumber {
                        fileInfos.append(DiskCacheObject(key: key, cost: fileSize.unsignedLongValue, date: date))
                    }
                }
                catch {
                    return false
                }
            }
            fileInfos.sortInPlace { $0.date.timeIntervalSince1970 < $1.date.timeIntervalSince1970 }
            fileInfos.forEach {
                _cache.set(object: $0, forKey: $0.key)
            }
        } catch {
            return false
        }
        return true
    }
    
    private func _unsafeTrim(toCount countLimit: UInt) {
        if var lastObject: DiskCacheObject = _cache.lastObject() {
            while (_cache.count > countLimit) {
                let fileURL = _generateFileURL(lastObject.key, path: cacheURL)
                if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(fileURL.absoluteString)
                        _cache.removeLastObject()
                        guard let newLastObject = _cache.lastObject() else { break }
                        lastObject = newLastObject
                    } catch {}
                }
            }
        }
    }
    
    private func _unsafeTrim(toCost costLimit: UInt) {
        if var lastObject: DiskCacheObject = _cache.lastObject() {
            while (_cache.cost > costLimit) {
                let fileURL = _generateFileURL(lastObject.key, path: cacheURL)
                if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(fileURL.absoluteString)
                        _cache.removeLastObject()
                        guard let newLastObject = _cache.lastObject() else { break }
                        lastObject = newLastObject
                    } catch {}
                }
            }
        }
    }
    
    private func _unsafeTrim(toAge ageLimit: NSTimeInterval) {
        if var lastObject: DiskCacheObject = _cache.lastObject() {
            while (lastObject.date.timeIntervalSince1970 < NSDate().timeIntervalSince1970 - ageLimit) {
                let fileURL = _generateFileURL(lastObject.key, path: cacheURL)
                if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(fileURL.absoluteString)
                        _cache.removeLastObject()
                        guard let newLastObject = _cache.lastObject() else { break }
                        lastObject = newLastObject
                    } catch {}
                }
            }
        }
    }
    
    private func _unsafeObject(forKey key: String) -> AnyObject? {
        let fileURL = _generateFileURL(key, path: cacheURL)
        var object: AnyObject? = nil
        let date: NSDate = NSDate()
        if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
            object = NSKeyedUnarchiver.unarchiveObjectWithFile(fileURL.absoluteString)
            do {
                try NSFileManager.defaultManager().setAttributes([NSFileModificationDate : date], ofItemAtPath: fileURL.path!)
                if object != nil {
                    if let diskCacheObj = _cache.object(forKey: key) {
                        diskCacheObj.date = date
                    }
                }
            } catch {
                
            }
        }
        return object
    }
    
    private func _generateFileURL(key: String, path: NSURL) -> NSURL {
        return path.URLByAppendingPathComponent(key)
    }
    
    private func _lock() {
        dispatch_semaphore_wait(_semaphoreLock, DISPATCH_TIME_FOREVER)
    }
    
    private func _unlock() {
        dispatch_semaphore_signal(_semaphoreLock)
    }
}
