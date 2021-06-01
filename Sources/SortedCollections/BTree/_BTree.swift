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
internal struct _BTree<Key: Comparable, Value> {
  @usableFromInline
  typealias Element = (key: Key, value: Value)
  
  @usableFromInline
  typealias Node = _Node<Key, Value>
  
  /// The underlying node behind this local BTree
  @usableFromInline
  internal var root: Node
  
  @inlinable
  @inline(__always)
  internal init() {
    self.root = Node(isLeaf: false, withCapacity: BTREE_NODE_CAPACITY)
  }
  
  @inlinable
  @inline(__always)
  internal init(rootedAt root: Node) {
    self.root = root
  }
}

// MARK: Mutating Operations
extension _BTree {
  @inlinable
  @inline(__always)
  internal mutating func insertKey(_ key: Key, withValue value: Value) {
    let element = (key: key, value: value)
    if let splinter = self.root.update({ $0.insertElement(element) }) {
      self.root = splinter.toNode(from: root, withCapacity: self.root.capacity)
    }
  }
}

// MARK: Read Operations
extension _BTree {
  /// Returns a cursor to the first key that is equal to given key.
  /// - Returns: If found, returns a cursor to the element, or where
  ///     it would be if it did exist.
  @inlinable
  internal func findFirstKey(_ key: Key) -> Path? {
    return nil
  }
}
