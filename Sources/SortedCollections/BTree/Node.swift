//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

@usableFromInline
internal struct Node<Key: Comparable, Value> {
  @usableFromInline
  typealias Element = (key: Key, value: Value)
  
  @usableFromInline
  internal var keys: _Buffer<Key>.Pointer
  
  @usableFromInline
  internal var values: _Buffer<Value>.Pointer
  
  @usableFromInline
  internal var children: _Buffer<Node<Key, Value>>.Pointer
  
  @usableFromInline
  internal var count: Int
  
  @usableFromInline
  internal var capacity: Int
  
  @inlinable
  internal init(capacity: Int) {
    self.keys = _Buffer<Key>.create(capacity: capacity)
    self.values = _Buffer<Value>.create(capacity: capacity)
    self.children = _Buffer<Node<Key, Value>>.create(capacity: capacity + 1)
    self.count = 0
    self.capacity = capacity
  }
}

// MARK: CoW
extension Node {
  
  /// Allows **read-only** access to the underlying data behind the node.
  ///
  /// - Parameter body: A closure with a handle which allows interacting with the node
  @inlinable
  @inline(__always)
  internal func read<R>(_ body: (_UnsafeHandle) throws -> R) rethrows -> R {
    try self.keys.withUnsafeMutablePointers { keyHeader, keys in
      try self.values.withUnsafeMutablePointers { valueHeader, values in
        try self.children.withUnsafeMutablePointers { childrenHeader, children in
          let handle = _UnsafeHandle(
            keyHeader: keyHeader,
            valueHeader: valueHeader,
            childrenHeader: childrenHeader,
            keys: keys,
            values: values,
            children: children
          )
          return try body(handle)
        }
      }
    }
  }
  
  /// Allows mutable access to the underlying data behind the node.
  ///
  /// - Parameter body: A closure with a handle which allows interacting with the node
  @inlinable
  @inline(__always)
  internal mutating func update<R>(_ body: (_UnsafeMutableHandle) throws -> R) rethrows -> R {
    self.ensureUnique()
    return try self.read { try body(_UnsafeMutableHandle($0)) }
  }
  
  /// Ensure that this storage refers to a uniquely held buffer by copying
  /// elements if necessary.
  @inlinable
  @inline(__always)
  internal mutating func ensureUnique() {
    if !keys.isUniqueReference() {
      self.keys = _Buffer<Key>.copy(from: keys, capacity: capacity)
    }
    
    if !values.isUniqueReference() {
      self.values = _Buffer<Value>.copy(from: values, capacity: capacity)
    }
    
    if !children.isUniqueReference() {
      self.children = _Buffer<Node<Key, Value>>.copy(from: children, capacity: capacity)
    }
  }
  
}

//
//extension Node {
//  typealias Splinter = (median: Element, rightChild: Node<Key, Value>)
//
//  /// Inserts a node, if a split occurs this returns a tuple of the new right-child and the
//  /// node that should be propogated upward
//  internal func insertValue(_ value: Value, forKey key: Key) -> Splinter? {
//    let targetIndex = self.lastIndex(of: key)
//
//    // TODO: specialize and optimize cases to minimize element shuffling
//    self.keys.insert(key, at: targetIndex)
//    self.values.insert(value, at: targetIndex)
//
//    // If we need to split
//    if count == capacity {
//      let medianIndex = (count + 1) / 2
//      let medianElement = (key: self.keys[medianIndex], value: self.values[medianIndex])
//
//      // Create the new right node
//      let rightValues = (medianIndex + 1)...
//      let rightNode = Node<Key, Value>(
//        capacity: capacity,
//        keys: Array(self.keys[rightValues]),
//        values: Array(self.values[rightValues]),
//        children: Array(self.children[rightValues])
//      )
//
//      self.keys.removeLast(count - medianIndex)
//      self.count = medianIndex + 1
//
//      _checkInvariants()
//      return (median: medianElement, rightChild: rightNode)
//    } else {
//      self.count += 1
//
//      _checkInvariants()
//      return nil
//    }
//  }
//}
