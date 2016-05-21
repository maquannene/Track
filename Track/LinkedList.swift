//
//  LinkedList.swift
//  Demo
//
//  Created by 马权 on 5/20/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation

class Node<T: Equatable> {
    
    weak var preNode: Node?
    weak var nextNode: Node?
    let data: T
    
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
}

class LRU<T: LRUObjectBase> {
    
    private typealias NodeType = Node<T>
    
    private var _dic: NSMutableDictionary = NSMutableDictionary()
    
    private let _linkedList: LinkedList = LinkedList<T>()

    var count: UInt {
        return _linkedList.count
    }
    
    var countLimit: UInt = UInt.max {
        didSet {
            trimToCount(countLimit)
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
        if _linkedList.count > countLimit {
            deleteTailNode()
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
        }
    }
    
    /**
     remove all objects
     */
    func removeAllObjects() {
        _dic = NSMutableDictionary()
        _linkedList.removeAllNodes()
    }
    
    /**
     according to LRU, remove number of the value of the least frequently used
     
     - parameter count: number of the value
     */
    func trimToCount(count: UInt) {
        let currentCount: UInt = _linkedList.count
        if currentCount < count {
            return
        }
        var newTailNode: NodeType? = _linkedList.tailNode
        for _ in 0 ..< currentCount - count {
            _dic.removeObjectForKey(newTailNode!.data.key)
            newTailNode = newTailNode?.preNode
            _linkedList.count -= 1
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
    
    /**
     delete tail node from link and list
     */
    private func deleteTailNode() {
        if let tailNode = _linkedList.tailNode {
            _dic.removeObjectForKey(tailNode.data.key)
            _linkedList.removeNode(tailNode)
        }
    }
    
}