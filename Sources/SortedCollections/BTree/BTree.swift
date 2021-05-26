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

// Totally arbitrary node capacity for BTree
@usableFromInline
internal let BTREE_NODE_CAPACITY = 100

@usableFromInline
internal struct BTree<Key: Comparable, Value> {
  @usableFromInline
  typealias Element = (key: Key, value: Value)
  
  /// The underlying node behind this local BTree
  @usableFromInline
  internal var root: Node<Key, Value>
  
  @inlinable
  @inline(__always)
  internal init() {
    self.root = Node(withCapacity: BTREE_NODE_CAPACITY)
  }
  
  @inlinable
  @inline(__always)
  internal init(_rootedAt root: Node<Key, Value>) {
    self.root = root
  }
}

// MARK: Mutating Operations
extension BTree {
  @inlinable
  @inline(__always)
  internal mutating func insertKey(_ key: Key, withValue value: Value) {
    let element = (key: key, value: value)
    if let splinter = root.update({ $0.insertElement(element) }) {
      self.root = splinter.toNode(withCapacity: BTREE_NODE_CAPACITY)
    }
  }
}

// MARK: Read Operations
extension BTree {
  /// Returns a cursor to the first key that is equal to given key.
  /// - Returns: If found, returns a cursor to the element, or where
  ///     it would be if it did exist.
  @inlinable
  internal func findFirstKey(_ key: Key) -> Cursor? {
    return nil
  }
}
