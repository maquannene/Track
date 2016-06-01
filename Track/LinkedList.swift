//The MIT License (MIT)
//
//Copyright (c) 2016 U Are My SunShine
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

import Foundation
import QuartzCore

protocol LRUObjectBase: Equatable {
    var key: String { get }
    var cost: UInt { get set }
}

class LRUGenerate<T: LRUObjectBase> : GeneratorType {
    
    typealias Element = T

    private var node: Node<T>?
    
    private init(node: Node<T>?) {
        self.node = node
    }
    
    func next() -> Element? {
        if let node = node {
            self.node = node.nextNode
            return node.data
        }
        else {
            return nil
        }
    }
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

    func allObjects() -> [T] {
        var objects: [T] = [T]()
        var indexNode: NodeType? = _linkedList.headNode
        while (true) {
            if let node = indexNode {
                objects.append(node.data)
                indexNode = node.nextNode
            }
            else {
                break
            }
        }
        return objects
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
    
    func firstObject() -> T? {
        return _linkedList.headNode?.data
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

extension LRU : SequenceType {
    typealias Generator = LRUGenerate<T>
    
    @warn_unused_result
    func generate() -> LRUGenerate<T> {
        var generatror: LRUGenerate<T>
        generatror = LRUGenerate(node: _linkedList.headNode)
        return generatror
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
        if node.data == headNode?.data {
            headNode = node.nextNode
            headNode?.preNode = nil
        }
        else if node.data == tailNode?.data {
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
        var node: Node<T>?
        if index < count / 2 {
            node = headNode
            for _ in 1 ... index {
                node = node?.nextNode
            }
        }
        else {
            node = tailNode
            for _ in 1 ... count - index - 1 {
                node = node?.preNode
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
