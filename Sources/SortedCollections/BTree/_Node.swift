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
internal struct _Node<Key: Comparable, Value> {
  @usableFromInline
  typealias Element = (key: Key, value: Value)
  
  @usableFromInline
  internal var keys: Storage<Key>
  
  @usableFromInline
  internal var values: Storage<Value>
  
  @usableFromInline
  internal var children: Storage<_Node<Key, Value>>?
  
  /// The total number of key-value pairs this node can store
  @usableFromInline
  internal var capacity: Int
  
  @inlinable
  @inline(__always)
  internal init(isLeaf: Bool, withCapacity capacity: Int) {
    assert(capacity > 0, "Capacity must be positive.")
    self.keys = Storage(capacity: capacity)
    self.values = Storage(capacity: capacity)
    self.children = isLeaf ? nil : Storage(capacity: capacity + 1)
    self.capacity = capacity
  }
}

// MARK: CoW
extension _Node {
  
  /// Allows **read-only** access to the underlying data behind the node.
  ///
  /// - Parameter body: A closure with a handle which allows interacting with the node
  @inlinable
  @inline(__always)
  internal func read<R>(_ body: (UnsafeHandle) throws -> R) rethrows -> R {
    try self.keys.buffer.withUnsafeMutablePointers { keyHeader, keys in
      try self.values.buffer.withUnsafeMutablePointers { valueHeader, values in
        if let children = self.children {
          return try children.buffer.withUnsafeMutablePointers { childrenHeader, children in
            let handle = UnsafeHandle(
              keyHeader: keyHeader,
              valueHeader: valueHeader,
              childrenHeader: childrenHeader,
              keys: keys,
              values: values,
              children: children,
              capacity: self.capacity,
              isMutable: false
            )
            return try body(handle)
          }
        } else {
          let handle = UnsafeHandle(
            keyHeader: keyHeader,
            valueHeader: valueHeader,
            childrenHeader: nil,
            keys: keys,
            values: values,
            children: nil,
            capacity: self.capacity,
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
  /// - Returns: The closure's return value, if exists
  @inlinable
  @inline(__always)
  internal mutating func update<R>(_ body: (UnsafeHandle) throws -> R) rethrows -> R {
    self.ensureUnique()
    return try self.read { handle in
      defer { handle.checkInvariants() }
      return try body(UnsafeHandle(mutableCopyOf: handle))
    }
  }
  
  /// Ensure that this storage refers to a uniquely held buffer by copying
  /// elements if necessary.
  @inlinable
  @inline(__always)
  internal mutating func ensureUnique() {
    self.keys.ensureUnique(capacity: capacity)
    self.values.ensureUnique(capacity: capacity)
    self.children?.ensureUnique(capacity: capacity + 1)
  }
}

// MARK: Equatable
extension _Node: Equatable {
  @usableFromInline
  internal static func ==(lhs: _Node, rhs: _Node) -> Bool {
    return lhs.keys.buffer.buffer === rhs.keys.buffer.buffer &&
      lhs.values.buffer.buffer === rhs.values.buffer.buffer &&
      lhs.children?.buffer.buffer === rhs.children?.buffer.buffer
  }
}
