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
  internal var keys: _Storage<Key>
  
  @usableFromInline
  internal var values: _Storage<Value>
  
  @usableFromInline
  internal var children: _Storage<Node<Key, Value>>
  
  /// The total number of key-value pairs this node can store
  @usableFromInline
  internal var capacity: Int
  
  /// Creates an empty node with given capacity
  @inlinable
  internal init(withCapacity capacity: Int) {
    assert(capacity > 0, "Capacity must be positive.")
    self.keys = _Storage(capacity: capacity)
    self.values = _Storage(capacity: capacity)
    self.children = _Storage(capacity: capacity + 1)
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
    try self.keys.buffer.withUnsafeMutablePointers { keyHeader, keys in
      try self.values.buffer.withUnsafeMutablePointers { valueHeader, values in
        try self.children.buffer.withUnsafeMutablePointers { childrenHeader, children in
          let handle = _UnsafeHandle(
            keyHeader: keyHeader,
            valueHeader: valueHeader,
            childrenHeader: childrenHeader,
            keys: keys,
            values: values,
            children: children,
            capacity: capacity,
            isMutable: false
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
  internal mutating func update<R>(_ body: (_UnsafeHandle) throws -> R) rethrows -> R {
    self.ensureUnique()
    return try self.read { try body(_UnsafeHandle(mutableCopyOf: $0)) }
  }
  
  /// Ensure that this storage refers to a uniquely held buffer by copying
  /// elements if necessary.
  @inlinable
  @inline(__always)
  internal mutating func ensureUnique() {
    self.keys.ensureUnique(capacity: capacity)
    self.values.ensureUnique(capacity: capacity)
    self.children.ensureUnique(capacity: capacity + 1)
  }
  
}
