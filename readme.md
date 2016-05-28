<p align="left"><img src="http://ww4.sinaimg.cn/large/65312d9agw1f48moyot15j20du04odg6.jpg" width="300" height="90"/></p>

![Language](https://img.shields.io/badge/language-Swift%202.2-orange.svg)
[![Pod Version](http://img.shields.io/cocoapods/v/Track.svg?style=flat)](http://cocoadocs.org/docsets/Track/)
[![Pod Platform](http://img.shields.io/cocoapods/p/Track.svg?style=flat)](http://cocoadocs.org/docsets/Track/)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/maquannene/Track/blob/master/LICENSE)

Track is a thread safe cache write by Swift. Composed of DiskCache and MemoryCache which support LRU.

## Features

* Thread safe: Implement by `dispatch_semaphore_t lock` and `DISPATCH_QUEUE_CONCURRENT`. Cache methods are thread safe and no deadlock.

* LRU: Implement by linkedlist, it`s fast. it You can manage a cache through functions to limit size, age of entries and memory usage to eliminate least recently used object.

* Async and Sync: Cache support async and sync operation.

* Support subscript and for ... in.

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

**New features: for ... in**

MemoryCache support thread safe `for ... in` loops by `SequenceType` and `GeneratorType`

```swift
memoryCache.trim(toCount: 5)

for i in 1 ... 10 {
    memoryCache.set(object: "\(i)", forKey: "\(i)")
}

for object in memoryCache {
    print(object)
}

```

```ruby
output: 10 9 8 7 6

```

## Installation

**CocoaPods**

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

pod 'Track'
```

If you want to use the new features of Track

```ruby
pod 'Track', :git => 'https://github.com/maquannene/Track.git'
```

**Carthage**

```ruby
github "maquannene/Track"
```

## Thanks

Thanks YYCache，PINCache very much. Some ideas from them.

## License

Track is released under the MIT license.