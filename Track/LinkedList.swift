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

protocol LRUObject {
    
    var key: String { get }
    var cost: UInt { get set }
}

class LRUGenerator<T: LRUObject> : FastGeneratorType {
    
    typealias Element = T

    fileprivate let linkedListGenerator: LinkedListGenerator<T>
    
    fileprivate let lru: LRU<T>
    
    fileprivate init(linkedListGenerator: LinkedListGenerator<T>, lru: LRU<T>) {
        self.linkedListGenerator = linkedListGenerator
        self.lru = lru
    }
    
    
    func next() -> Element? {
        if let node = linkedListGenerator.next() {
            lru._linkedList.bringNodeToHead(node)
            return node.data
        }
        return nil
    }
    
    func shift() {
        if let node = linkedListGenerator.next() {
            lru._linkedList.bringNodeToHead(node)
        }
    }
}

class LRU<T: LRUObject> {
    
    fileprivate typealias NodeType = Node<T>
    
    var count: UInt {
        return _linkedList.count
    }
    
    fileprivate(set) var cost: UInt = 0
    
    fileprivate var _dic: NSMutableDictionary = NSMutableDictionary()
    
    fileprivate let _linkedList: LinkedList = LinkedList<T>()
    
    func set(object: T, forKey key: String) {
        if let node: NodeType = _dic.object(forKey: key) as? NodeType {
            cost -= node.data.cost
            cost += object.cost
            node.data = object
            _linkedList.bringNodeToHead(node)
        }
        else {
            let node: NodeType = Node(data: object)
            cost += object.cost
            _dic.setObject(node, forKey: key as NSCopying)
            _linkedList.insertNode(node, atIndex: 0)
        }
    }

    func object(forKey key: String) -> T? {
        if let node: NodeType = _dic.object(forKey: key) as? NodeType {
            _linkedList.bringNodeToHead(node)
            return node.data
        }
        return nil
    }

    func allObjects() -> [T] {
        var objects: [T] = [T]()
        var indexNode: NodeType? = _linkedList.headNode
        while (true) {
            if let node: NodeType = indexNode {
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
        if let node: NodeType = _dic.object(forKey: key) as? NodeType {
            _dic.removeObject(forKey: key)
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
        if let lastNode: NodeType = _linkedList.tailNode as NodeType? {
            _dic.removeObject(forKey: lastNode.data.key)
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
                _ = removeObject(forKey: key)
            }
        }
    }
}

extension LRU : Sequence {
    
    typealias Iterator = LRUGenerator<T>
    
    
    func makeIterator() -> LRUGenerator<T> {
        var generatror: LRUGenerator<T>
        generatror = LRUGenerator(linkedListGenerator: _linkedList.makeIterator(), lru: self)
        return generatror
    }
}

private class Node<T> {
    
    weak var preNode: Node?
    weak var nextNode: Node?
    var data: T
    
    init(data: T) {
        self.data = data
    }
}

private class LinkedListGenerator<T> : FastGeneratorType {
    
    typealias Element = Node<T>
    
    var node: Node<T>?
    
    init(node: Node<T>?) {
        self.node = node
    }
    
    
    func next() -> Element? {
        if let node: Element = self.node {
            self.node = node.nextNode
            return node
        }
        else {
            return nil
        }
    }
    
    func shift() {
        self.node = self.node?.nextNode
    }
}

private class LinkedList<T> {
    
    var count: UInt = 0
    weak var headNode: Node<T>?
    weak var tailNode: Node<T>?
    
    init() {
        
    }

    func insertNode(_ node: Node<T>, atIndex index: UInt) {
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

    func bringNodeToHead(_ node: Node<T>) {
        if node === headNode {
            return
        }
        if node === tailNode {
            tailNode = node.preNode
            tailNode?.nextNode = nil
        }
        else {
            node.nextNode?.preNode = node.preNode
            node.preNode?.nextNode = node.nextNode
        }
        
        node.preNode = nil
        node.nextNode = headNode
        headNode?.preNode = node
        headNode = node
    }
    
    func removeNode(_ node: Node<T>) {
        if count == 0 {
            return
        }
        if node === headNode {
            headNode = node.nextNode
            headNode?.preNode = nil
        }
        else if node === tailNode {
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
            for _ in 1 ... count - (index - 1) {
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

extension LinkedList : Sequence {
    
    fileprivate typealias Iterator = LinkedListGenerator<T>
    
    
    fileprivate func makeIterator() -> LinkedListGenerator<T> {
        var generatror: LinkedListGenerator<T>
        generatror = LinkedListGenerator(node: headNode)
        return generatror
    }
}
