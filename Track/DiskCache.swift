
//  DiskCache.swift
//  Demo
//
//  Created by 马权 on 5/17/16.
//  Copyright © 2016 马权. All rights reserved.
//

/*
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

class DiskCacheObject: LRUObjectBase {
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

func == (lhs: DiskCacheObject, rhs: DiskCacheObject) -> Bool {
    return lhs.key == rhs.key
}

public typealias DiskCacheAsyncCompletion = (cache: DiskCache?, key: String?, object: AnyObject?) -> Void

 private func _generateFileURL(key: String, path: NSURL) -> NSURL {
    return path.URLByAppendingPathComponent(key)
}

public class DiskCache {
    
    public let name: String
    
    public let cacheURL: NSURL
    
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
    
    private var _countLimit: UInt = UInt.max
    public var countLimit: UInt {
        set {
            lock()
            _countLimit = newValue
            unlock()
            trimToCount(newValue)
        }
        get {
            lock()
            let countLimit = _countLimit
            unlock()
            return countLimit
        }
    }
    
    private var _costLimit: UInt = UInt.max
    public var costLimit: UInt {
        set {
            lock()
            _costLimit = newValue
            unlock()
            trimToCost(newValue)
        }
        get {
            lock()
            let costLimit = _costLimit
            unlock()
            return costLimit
        }
    }
    
    private var _ageLimit: NSTimeInterval = DBL_MAX
    public var ageLimit: NSTimeInterval {
        set {
            lock()
            _ageLimit = newValue
            unlock()
            trimToAge(newValue)
        }
        get {
            lock()
            let ageLimit = _ageLimit
            unlock()
            return ageLimit
        }
    }
    
    private let _cache: LRU = LRU<DiskCacheObject>()
    
    private let _queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + (String(DiskCache)), DISPATCH_QUEUE_CONCURRENT)
    
    private let _semaphoreLock: dispatch_semaphore_t = dispatch_semaphore_create(1)
    
    //  MARK: 
    //  MARK: Public
    public static let shareInstance = DiskCache(name: TrackCacheDefauleName)
    
    public init?(name: String, path: String) {
        if name.characters.count == 0 || path.characters.count == 0 {
            return nil
        }
        self.name = name
        self.cacheURL = NSURL(string: path)!.URLByAppendingPathComponent(TrackCachePrefix + name, isDirectory: false)
        
        lock()
        dispatch_async(_queue) {
            self._createCacheDir()
            self._loadFilesInfo()
            self.unlock()
        }
    }
    
    public convenience init?(name: String) {
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
    
    //  MARK: Async
    /**
     ASync method to operate cache
     */
    public func set(object object: NSCoding, forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: object); return }
            strongSelf.set(object: object, forKey: key)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    public func object(forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            let object = strongSelf.object(forKey: key)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    public func removeObject(forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            strongSelf.removeObject(forKey: key)
            completion?(cache: strongSelf, key: key, object: nil)
        }
    }
    
    public func removeAllObjects(completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.removeAllObjects()
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    public func trimToCount(countLimit: UInt, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trimToCount(countLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    public func trimToCost(costLimit: UInt, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trimToCost(costLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    public func trimToAge(ageLimit: NSTimeInterval, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(_queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.trimToAge(ageLimit)
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    //  MARK: Sync
    /**
     Sync method to operate cache
     */
    public func set(object object: NSCoding, forKey key: String) {
        let fileURL = _generateFileURL(key, path: cacheURL)
        lock()
        
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
            _unsafeTrimToCost(_costLimit)
        }
        if _cache.count > _countLimit {
            _unsafeTrimToCount(_countLimit)
        }
        unlock()
    }
    
    public func object(forKey key: String) -> AnyObject? {
        let fileURL = _generateFileURL(key, path: cacheURL)
        var object: AnyObject? = nil
        lock()
        
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
        unlock()
        return object
    }
    
    public func removeObject(forKey key: String) {
        let fileURL = _generateFileURL(key, path: cacheURL)
        lock()
        if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(fileURL.absoluteString)
                _cache.removeObject(forKey: key)
            } catch {}
        }
        unlock()
    }
    
    public func removeAllObjects() {
        lock()
        if NSFileManager.defaultManager().fileExistsAtPath(self.cacheURL.absoluteString) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(self.cacheURL.absoluteString)
                _cache.removeAllObjects()
            } catch {}
        }
        unlock()
    }
    
    public func trimToCount(countLimit: UInt) {
        if self.totalCount <= countLimit {
            return
        }
        if countLimit == 0 {
            removeAllObjects()
            return
        }
        lock()
        _unsafeTrimToCount(countLimit)
        unlock()
    }
    
    public func trimToCost(costLimit: UInt) {
        if self.totalCost <= costLimit {
            return
        }
        if costLimit == 0 {
            removeAllObjects()
            return
        }
        lock()
        _unsafeTrimToCost(costLimit)
        unlock()
    }
    
    public func trimToAge(ageLimit: NSTimeInterval) {
        if ageLimit <= 0 {
            removeAllObjects()
            return
        }
        lock()
        _unsafeTrimToAge(ageLimit)
        unlock()
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
    //  MARK: Private
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
    
    private func _unsafeTrimToCount(countLimit: UInt) {
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
    
    private func _unsafeTrimToCost(costLimit: UInt) {
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
    
    private func _unsafeTrimToAge(ageLimit: NSTimeInterval) {
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
}

//  MARK: ThreadSafeProtocol
private extension DiskCache {
    func lock() {
        dispatch_semaphore_wait(_semaphoreLock, DISPATCH_TIME_FOREVER)
    }
    
    func unlock() {
        dispatch_semaphore_signal(_semaphoreLock)
    }
}
