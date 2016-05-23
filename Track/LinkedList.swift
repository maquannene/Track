//
//  LinkedList.swift
//  Demo
//
//  Created by 马权 on 5/20/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation
import QuartzCore

protocol LRUObjectBase: Equatable {
    var key: String { get }
    var cost: UInt { get set }
}

class LRU<T: LRUObjectBase> {
    
    private typealias NodeType = Node<T>
    
    var count: UInt {
        return _linkedList.count
    }
    
    private(set) var cost: UInt = 0
    
    private var _dic: NSMutableDictionary = NSMutableDictionary()
    
    private let _linkedList: LinkedList = LinkedList<T>()
    
    func set(object object: T, forKey key: String) {
        if let node = _dic.objectForKey(key) as? NodeType {
            cost -= node.data.cost
            cost += object.cost
            node.data = object
            _linkedList.removeNode(node)
            _linkedList.insertNode(node, atIndex: 0)
        }
        else {
            let node = Node(data: object)
            cost += object.cost
            _dic.setObject(node, forKey: node.data.key)
            _linkedList.insertNode(node, atIndex: 0)
        }
    }

    func object(forKey key: String) -> T? {
        if let node = _dic.objectForKey(key) as? NodeType {
            _linkedList.removeNode(node)
            _linkedList.insertNode(node, atIndex: 0)
            return node.data
        }
        return nil
    }

    func removeObject(forKey key: String) -> T? {
        if let node = _dic.objectForKey(key) as? NodeType {
            _dic.removeObjectForKey(node.data.key)
            _linkedList.removeNode(node)
            cost -= node.data.cost
            return node.data
        }
        return nil
    }

    func removeAllObjects() {
        _dic = NSMutableDictionary()
        _linkedList.removeAllNodes()
        cost = 0
    }
    
    func removeLastObject() {
        if let lastNode = _linkedList.tailNode as NodeType? {
            _dic.removeObjectForKey(lastNode.data.key)
            _linkedList.removeNode(lastNode)
            cost -= lastNode.data.cost
            return
        }
    }
    
    func lastObject() -> T? {
        return _linkedList.tailNode?.data
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

private class Node<T: Equatable> {
    weak var preNode: Node?
    weak var nextNode: Node?
    var data: T
    
    init(data: T) {
        self.data = data
    }
}

private class LinkedList<T: Equatable> {
    
    var count: UInt = 0
    weak var headNode: Node<T>?
    weak var tailNode: Node<T>?
    
    init() {
        
    }

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
    
    func removeAllNodes() {
        headNode = nil
        tailNode = nil
        count = 0
    }
}