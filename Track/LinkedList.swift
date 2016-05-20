//
//  LinkedList.swift
//  Demo
//
//  Created by 马权 on 5/20/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation

class Node<T> {
    
    private(set) weak var preNode: Node?
    private(set) weak var nextNode: Node?
    let key: String
    let value: T
    
    init(key: String, value: T) {
        self.key = key
        self.value = value
    }
}

class LinkedList<T> {
    
    private typealias NodeType = Node<T>
    
    private(set) var count = 0
    private(set) weak var headNode: Node<T>?
    private(set) weak var tailNode: Node<T>?
    
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
    private func insertNode(node: NodeType, atIndex index: Int) {
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
    private func removeNode(node: NodeType) {
        if count == 0 {
            return
        }
        if node.key == headNode!.key {
            headNode = node.nextNode
            headNode?.preNode = nil
        }
        else if node.key == tailNode!.key {
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
    private func findNode(atIndex index: Int) -> NodeType? {
        if count == 0 {
            return nil
        }
        var node: NodeType!
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
    private func removeAllNodes() {
        headNode = nil
        tailNode = nil
        count = 0
    }
}

class LRU<T> {
    
    private typealias NodeType = Node<T>
    
    private let dic: NSMutableDictionary = NSMutableDictionary()
    
    private let linkedList: LinkedList = LinkedList<T>()
    
    var count: Int {
        get {
            return linkedList.count
        }
    }
    
    /**
     set object for specified key, and add to head
     
     - parameter object: object
     - parameter key:    key
     */
    func set(object object: T, forKey key: String) {
        let node = NodeType(key: key, value: object)
        dic.setObject(node, forKey: node.key)
        addNodeAtHead(node)
    }
    
    /**
     get object according the specified key
     
     - parameter key: key
     
     - returns: optional object
     */
    func object(forKey key: String) -> T? {
        if let node = dic.objectForKey(key) as? NodeType {
            moveNodeToHead(node)
            return node.value
        }
        return nil
    }
    
    /**
     remove object according specified key
     
     - parameter key:
     */
    func removeObject(forKey key: String) {
        if let node = dic.objectForKey(key) as? NodeType {
            deleteNode(node)
        }
    }
    
    /**
     remove all objects
     */
    func removeAllObjects() {
        deleteAllNodes()
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
     add node to link and list at head
     
     - parameter node: added node
     */
    private func addNodeAtHead(node: NodeType) {
        dic.setObject(node, forKey: node.key)
        linkedList.insertNode(node, atIndex: 0)
    }
    /**
     delete node from link and list
     
     - parameter node: deleted node
     */
    private func deleteNode(node: NodeType) {
        dic.removeObjectForKey(node.key)
        linkedList.removeNode(node)
    }
    /**
     move node to head at link
     
     - parameter node: node
     */
    private func moveNodeToHead(node: NodeType) {
        linkedList.removeNode(node)
        linkedList.insertNode(node, atIndex: 0)
    }
    /**
     delete tail node from link and list
     */
    private func deleteTailNode() {
        if let tailNode = linkedList.tailNode {
            dic.removeObjectForKey(tailNode.key)
            linkedList.removeNode(tailNode)
        }
    }
    /**
     delete all node from link and list
     */
    private func deleteAllNodes() {
        dic.removeAllObjects()
        linkedList.removeAllNodes()
    }
    
}