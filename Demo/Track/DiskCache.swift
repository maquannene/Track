//
//  DiskCache.swift
//  Demo
//
//  Created by 马权 on 5/17/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation

public typealias DiskCacheAsyncCompletion = (cache: DiskCache, key: String, value: AnyObject?)

let TrackDiskCacheDefauleName: String = "TrackDiskCache"

public class DiskCache {
    
    public var name: String
    
    public var cacheURL: NSURL
    
    private let queue: dispatch_queue_t = dispatch_queue_create("com.maquan.\(TrackDiskCacheDefauleName)", DISPATCH_QUEUE_CONCURRENT)

    public static let shareInstance = DiskCache(name: TrackDiskCacheDefauleName)
    
    public init(name: String!, path: String!) {
        self.name = name
        self.cacheURL = NSURL(string: path)!.URLByAppendingPathComponent(name, isDirectory: false)
    }
    
    public convenience init(name: String!) {
        self.init(name: name, path: NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0])
    }
    
}
