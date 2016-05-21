//
//  LinkedList.swift
//  Demo
//
//  Created by 马权 on 5/20/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation
import QuartzCore

class Node<T: Equatable> {
    weak var preNode: Node?
    weak var nextNode: Node?
    var data: T
    
    init(data: T) {
        self.data = data
    }
}

class LinkedList<T: Equatable> {
    
    var count: UInt = 0
    weak var headNode: Node<T>?
    weak var tailNode: Node<T>?
    
    /**
     init a empty linkedList
     
     - returns: empty linkedList
     */
    init() {
        
    }
    
    /**
     add node to linked at index
     
     - parameter node:  node
     - parameter index: position
     */
    func insertNode(node: Node<T>, atIndex index: UInt) {
        if index > count {
            return
        }
        node.preNode = nil
        node.nextNode = nil
        if count == 0 {
            headNode = node
            tailNode = node
        }
        else {
            if index == 0 {
                node.nextNode = headNode
                headNode?.preNode = node
                headNode = node
            }
            else if index == count {
                node.preNode = tailNode
                tailNode?.nextNode = node
                tailNode = node
            }
            else {
                let preNode = findNode(atIndex: index - 1)
                node.nextNode = preNode?.nextNode
                node.preNode = preNode
                node.nextNode?.preNode = node
                preNode?.nextNode = node
            }
        }
        count += 1
    }
    
    /**
     remove node frome link
     
     - parameter node: removed node
     */
    func removeNode(node: Node<T>) {
        if count == 0 {
            return
        }
        if node.data == headNode!.data {
            headNode = node.nextNode
            headNode?.preNode = nil
        }
        else if node.data == tailNode!.data {
            tailNode = node.preNode
            tailNode?.nextNode = nil
        }
        else {
            node.preNode?.nextNode = node.nextNode
            node.nextNode?.preNode = node.preNode
        }
        count -= 1
    }
    
    /**
     search node frome link by index
     
     - parameter index: node index
     
     - returns: node
     */
    func findNode(atIndex index: UInt) -> Node<T>? {
        if count == 0 {
            return nil
        }
        var node: Node<T>!
        if index < count / 2 {
            node = headNode
            for _ in 1 ... index {
                node = node.nextNode
            }
        }
        else {
            node = tailNode
            for _ in 1 ... count - index - 1 {
                node = node.preNode
            }
        }
        return node
    }
    
    /**
     remove all nodes from link
     */
    func removeAllNodes() {
        headNode = nil
        tailNode = nil
        count = 0
    }
}

protocol LRUObjectBase: Equatable {
    var key: String { get }
    var value: AnyObject { get set }
    var cost: UInt { get set }
    var age: NSTimeInterval { get set }
}

class LRU<T: LRUObjectBase> {
    
    private typealias NodeType = Node<T>
    
    private var _dic: NSMutableDictionary = NSMutableDictionary()
    
    private let _linkedList: LinkedList = LinkedList<T>()
    
    var count: UInt {
        return _linkedList.count
    }
    
    private(set) var cost: UInt = 0
    
    var countLimit: UInt = UInt.max {
        didSet {
            trimToCount(countLimit)
        }
    }
    
    var costLimit: UInt = UInt.max {
        didSet {
            trimToCost(costLimit)
        }
    }
    
    var ageLimit: NSTimeInterval = DBL_MAX {
        didSet {
            trimToAge(ageLimit)
        }
    }
    
    /**
     Set object for specified key, and add to head.
     
     - parameter object: object
     - parameter key:    key
     */
    func set(object object: T, forKey key: String) {
        let node = Node(data: object)
        _dic.setObject(node, forKey: node.data.key)
        _linkedList.insertNode(node, atIndex: 0)
        
        cost += object.cost
        
        if cost > costLimit {
            trimToCost(costLimit)
        }
        
        if _linkedList.count > countLimit {
            trimToCount(countLimit)
        }
    }
    
    /**
     get object according the specified key
     
     - parameter key: key
     
     - returns: optional object
     */
    func object(forKey key: String) -> T? {
        if let node = _dic.objectForKey(key) as? NodeType {
            _linkedList.removeNode(node)
            _linkedList.insertNode(node, atIndex: 0)
            node.data.age = CACurrentMediaTime()
            return node.data
        }
        return nil
    }
    
    /**
     remove object according specified key
     
     - parameter key:
     */
    func removeObject(forKey key: String) {
        if let node = _dic.objectForKey(key) as? NodeType {
            _dic.removeObjectForKey(node.data.key)
            _linkedList.removeNode(node)
            cost -= node.data.cost
        }
    }
    
    /**
     remove all objects
     */
    func removeAllObjects() {
        _dic = NSMutableDictionary()
        _linkedList.removeAllNodes()
        cost = 0
    }
    
    /**
     according to LRU, remove number of the value of the least frequently used
     
     - parameter count: number of the value
     */
    func trimToCount(count: UInt) {
        if _linkedList.count < count {
            return
        }
        let trimCount: UInt = _linkedList.count - count
        var newTailNode: NodeType? = _linkedList.tailNode
        for _ in 0 ..< trimCount {
            _linkedList.count -= 1
            cost -= newTailNode!.data.cost
            _dic.removeObjectForKey(newTailNode!.data.key)
            newTailNode = newTailNode?.preNode
        }
        if newTailNode == nil {
            _linkedList.headNode = nil
        }
        newTailNode?.nextNode = nil
        _linkedList.tailNode = newTailNode
    }
    
    func trimToCost(cost: UInt) {
        if self.cost < cost {
            return
        }
        var newTailNode: NodeType? = _linkedList.tailNode
        while (self.cost > cost) {
            self.cost -= newTailNode!.data.cost
            _linkedList.count -= 1
            _dic.removeObjectForKey(newTailNode!.data.key)
            newTailNode = newTailNode?.preNode
        }
        if newTailNode == nil {
            _linkedList.headNode = nil
        }
        newTailNode?.nextNode = nil
        _linkedList.tailNode = newTailNode
    }
    
    func trimToAge(age: NSTimeInterval) {
        if self.ageLimit < age {
            return
        }
        var newTailNode: NodeType? = _linkedList.tailNode
        while (newTailNode != nil && newTailNode?.data.age < age) {
            self.cost -= newTailNode!.data.cost
            _linkedList.count -= 1
            _dic.removeObjectForKey(newTailNode!.data.key)
            newTailNode = newTailNode?.preNode
        }
        if newTailNode == nil {
            _linkedList.headNode = nil
        }
        newTailNode?.nextNode = nil
        _linkedList.tailNode = newTailNode
    }
    
    subscript(key: String) -> T? {
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