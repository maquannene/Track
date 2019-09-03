<p align="left"><img src="http://ww4.sinaimg.cn/large/65312d9agw1f48moyot15j20du04odg6.jpg" width="300" height="90"/></p>

![Language](https://img.shields.io/badge/language-Swift%203.0-orange.svg)
[![Pod Version](http://img.shields.io/cocoapods/v/Track.svg?style=flat)](http://cocoadocs.org/docsets/Track/)
[![Pod Platform](http://img.shields.io/cocoapods/p/Track.svg?style=flat)](http://cocoadocs.org/docsets/Track/)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/maquannene/Track/blob/master/LICENSE)

Track is a thread safe cache write by Swift. Composed of DiskCache and MemoryCache which support LRU.

## Features

* Thread safe: Implement by `dispatch_semaphore_t lock` and `DISPATCH_QUEUE_CONCURRENT`. Cache methods are thread safe and no deadlock.

* LRU: Implement by linkedlist, it`s fast. You can manage a cache through functions to limit size, age of entries and memory usage to eliminate least recently used object.

* Support async and sync operation.

* Cache implement `SequenceType` `Generator`, support `subscrip` `for ... in` `map` `flapmap` `filter`...

## Use

**Base use**

Support Sync and Async Set, Get, RemoveObject, RemoveAll and Subscript.

```swift
let track = Cache.shareInstance

track.set(object: "object", forKey: "key")

track.object(forKey: "key")

track.removeObject(forKey: "key") { (cache, key, object) in }

track.removeAllObjects { (cache, key, object) in }

track["key"] = "object"

print(track["key"])
```

**Other use**

MemoryCache and DiskCache has feature of LRU, so they can eliminate least recently used object according `countLimit`, `costLimit` and `ageLimit`.

```swift
let diskcache = DiskCache.shareInstance

diskcache.countLimit = 20

diskcache.costLimit = 1024 * 10

let memorycache = MemoryCache.shareInstance

memorycache.trim(toAge: 1000) { (cache, key, object) in }

memorycache.trim(toCount: 10) { (cache, key, object) in }
```

**New features: SequenceType Generator**

Cache support thread safe `for ... in` `map` `forEache`...

```swift
let cache: Cache = Cache.shareInstance

for i in 1 ... 5 {
    cache.set(object: "\(i)", forKey: "\(i)")
}

for object in cache {
    print(object)
}
```

```
output: ("5", 5) ("4", 4) ("3", 3) ("2", 2) ("1", 1)
```

```
cache.forEach {
    print($0)
}
```

```
output: ("1", 1) ("2", 2) ("3", 3) ("4", 4) ("5", 5)
```

```
let values = cache.map { return $0 }

print(values)
```

```
output: [("5", 5), ("4", 4), ("3", 3), ("2", 2), ("1", 1)]
```

## Installation

**CocoaPods**

Support Swift 5.0

```
pod 'Track', :git => 'https://github.com/maquannene/Track.git', :branch => 'master'
```

**Manually**

1. Download and drop ```/Track``` folder in your project.  
2. Congratulations! 

## Thanks

Thanks YYCache，PINCache very much. Some ideas from them.

## License

Track is released under the MIT license.

如果来自天朝[点击查看](https://github.com/maquannene/Track/blob/master/%E5%A6%82%E6%9E%9C%E4%BD%A0%E5%9C%A8%E5%A4%A9%E6%9C%9D.md)更多实现细节文章
