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
  
  /// The number of elements in this buffer
  @usableFromInline
  internal var count: Int
  
  /// The total number of key-value pairs this node can store
  @usableFromInline
  internal var capacity: Int
  
  /// Creates an empty node with given capacity
  @inlinable
  internal init(withCapacity capacity: Int) {
    assert(capacity > 0, "Capacity must be positive.")
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
