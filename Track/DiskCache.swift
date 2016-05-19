
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

public typealias DiskCacheAsyncCompletion = (cache: DiskCache?, key: String?, object: AnyObject?) -> Void

 private func _generateFileURL(key: String, path: NSURL) -> NSURL {
    return path.URLByAppendingPathComponent(key)
}

public class DiskCache {
    
    public let name: String
    
    public let cacheURL: NSURL
    
    private let queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + (String(DiskCache)), DISPATCH_QUEUE_CONCURRENT)
    
    private let semaphoreLock: dispatch_semaphore_t = dispatch_semaphore_create(1)
    
    //  MARK: 
    //  MARK: Public
    public static let shareInstance = DiskCache(name: TrackCacheDefauleName)
    
    public init?(name: String!, path: String) {
        if name.characters.count == 0 || path.characters.count == 0 {
            return nil
        }
        self.name = name
        self.cacheURL = NSURL(string: path)!.URLByAppendingPathComponent(TrackCachePrefix + name, isDirectory: false)
        
        lock()
        dispatch_async(queue) {
            self._createCacheDir()
            self.unlock()
        }
    }
    
    public convenience init?(name: String) {
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
    
    //  MARK: Async
    public func set(object object: NSCoding, forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: object); return }
            strongSelf.set(object: object, forKey: key)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    public func object(forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            let object = strongSelf.object(forKey: key)
            completion?(cache: strongSelf, key: key, object: object)
        }
    }
    
    public func removeObject(forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            strongSelf.removeObject(forKey: key)
            completion?(cache: strongSelf, key: key, object: nil)
        }
    }
    
    public func removeAllObject(completion: DiskCacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let strongSelf = self else { completion?(cache: nil, key: nil, object: nil); return }
            strongSelf.removeAllObject()
            completion?(cache: strongSelf, key: nil, object: nil)
        }
    }
    
    //  MARK: Sync
    public func set(object object: NSCoding, forKey key: String) {
        let fileURL = _generateFileURL(key, path: cacheURL)
        threadSafe { 
            let _ = NSKeyedArchiver.archiveRootObject(object, toFile: fileURL.absoluteString)
        }
    }
    
    public func object(forKey key: String) -> AnyObject? {
        let fileURL = _generateFileURL(key, path: cacheURL)
        var object: AnyObject? = nil
        threadSafe {
            if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
                object = NSKeyedUnarchiver.unarchiveObjectWithFile(fileURL.absoluteString)
            }
        }
        return object
    }
    
    public func removeObject(forKey key: String) {
        let fileURL = _generateFileURL(key, path: cacheURL)
        threadSafe { 
            if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(fileURL.absoluteString)
                } catch {}
            }
        }
    }
    
    public func removeAllObject() {
        threadSafe { 
            if NSFileManager.defaultManager().fileExistsAtPath(self.cacheURL.absoluteString) {
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(self.cacheURL.absoluteString)
                } catch {}
            }
        }
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
}

//  MARK: ThreadSafeProtocol
extension DiskCache: ThreadSafeProtocol {
    func lock() {
        dispatch_semaphore_wait(semaphoreLock, DISPATCH_TIME_FOREVER)
    }
    
    func unlock() {
        dispatch_semaphore_signal(semaphoreLock)
    }
}
