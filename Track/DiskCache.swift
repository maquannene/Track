
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

public typealias DiskCacheAsyncCompletion = (cache: DiskCache?, key: String, object: AnyObject?) -> Void

public class DiskCache {
    
    public var name: String
    
    public var cacheURL: NSURL
    
    private let queue: dispatch_queue_t = dispatch_queue_create(TrackCachePrefix + (String(DiskCache)), DISPATCH_QUEUE_CONCURRENT)
    
    private let semaphoreLock: dispatch_semaphore_t = dispatch_semaphore_create(1)
    
    public static let shareInstance = DiskCache(name: TrackCacheDefauleName)
    
    public init(name: String!, path: String) {
        self.name = name
        self.cacheURL = NSURL(string: path)!.URLByAppendingPathComponent(TrackCachePrefix + name, isDirectory: false)
        
        lock()
        dispatch_async(queue) {
            self.createCacheDir()
            self.unlock()
        }
    }
    
    public convenience init(name: String) {
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
    
    //  Async
    public func set(object object: NSCoding, forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let sSelf = self else { completion?(cache: nil, key: key, object: object); return }
            sSelf.set(object: object, forKey: key)
            completion?(cache: sSelf, key: key, object: object)
        }
    }
    
    public func object(forKey key: String, completion: DiskCacheAsyncCompletion?) {
        dispatch_async(queue) { [weak self] in
            guard let sSelf = self else { completion?(cache: nil, key: key, object: nil); return }
            let object = sSelf.object(forKey: key)
            completion?(cache: sSelf, key: key, object: object)
        }
    }
    
    //  Sync
    public func set(object object: NSCoding, forKey key: String) {
        lock()
        let fileURL = generateFileURL(key, path: cacheURL)
        let _ = NSKeyedArchiver.archiveRootObject(object, toFile: fileURL.absoluteString)
        unlock()
    }
    
    public func object(forKey key: String) -> AnyObject? {
        lock()
        let fileURL = generateFileURL(key, path: cacheURL)
        var object: AnyObject? = nil
        if NSFileManager.defaultManager().fileExistsAtPath(fileURL.absoluteString) {
            object = NSKeyedUnarchiver.unarchiveObjectWithFile(fileURL.absoluteString)
        }
        unlock()
        return object
    }
    
    private func createCacheDir() -> Bool {
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
    
    private func generateFileURL(key: String, path: NSURL) -> NSURL {
        return path.URLByAppendingPathComponent(key)
    }
    
    private func lock() {
        dispatch_semaphore_wait(semaphoreLock, DISPATCH_TIME_FOREVER)
    }
    
    private func unlock() {
        dispatch_semaphore_signal(semaphoreLock)
    }
}
