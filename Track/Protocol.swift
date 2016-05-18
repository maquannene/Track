//
//  CacheProtocol.swift
//  Demo
//
//  Created by 马权 on 5/18/16.
//  Copyright © 2016 马权. All rights reserved.
//

import Foundation

protocol ThreadSafeProtocol {
    func threadSafe(operate: (() -> Void)?)
    func lock()
    func unlock()
}

extension ThreadSafeProtocol {
    func threadSafe(operate: (() -> Void)?) {
        lock()
        operate?()
        unlock()
    }
}
