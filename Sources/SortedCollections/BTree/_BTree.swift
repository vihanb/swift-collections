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
internal let BTREE_NODE_CAPACITY = 3

@usableFromInline
internal struct _BTree<Key: Comparable, Value> {
  @usableFromInline
  typealias Element = (key: Key, value: Value)
  
  @usableFromInline
  typealias Node = _Node<Key, Value>
  
  /// The underlying node behind this local BTree
  @usableFromInline
  internal var root: Node
  
  // TODO: remove
  @usableFromInline
  internal var capacity: Int
  
  @inlinable
  @inline(__always)
  internal init(capacity: Int = BTREE_NODE_CAPACITY) {
    self.root = Node(withCapacity: capacity, isLeaf: true)
    self.capacity = capacity
  }
  
  @inlinable
  @inline(__always)
  internal init(rootedAt root: Node, capacity: Int = BTREE_NODE_CAPACITY) {
    self.root = root
    self.capacity = capacity
  }
}

// MARK: Mutating Operations
extension _BTree {
  @inlinable
  @inline(__always)
  internal mutating func insertKey(_ key: Key, withValue value: Value) {
    let element = (key: key, value: value)
    if let splinter = self.root.update({ $0.insertElement(element) }) {
      self.root = splinter.toNode(from: root, withCapacity: self.capacity)
    }
  }
}

// MARK: Write Operations
extension _BTree {
  /// Updates a B-Tree at a specific path, running uniqueness checks as it
  /// traverses the tree.
  @inlinable
  internal mutating func update(at path: Path, _ body: (Node.UnsafeHandle) -> Void) {
    func update(_ handle: Node.UnsafeHandle, depth: Int) {
      if depth == path.offsets.count {
        body(handle)
      } else {
        let offset = path.offsets[depth]
        handle[childAt: offset].update { update($0, depth: depth + 1) }
      }
    }
    
    self.root.update { update($0, depth: 0) }
  }
  
  /// Updates the corresponding value for a key in the tree.
  /// - Parameters:
  ///   - value: New value for the key.
  ///   - path: A valid path within the tree
  /// - Complexity: O(1)
  @inlinable
  internal mutating func setValue(_ value: Value, at path: Path) {
    // TODO: this involves two tree descents. One to find the key, another
    // to run the update
    self.update(at: path) { handle in
      handle[valueAt: path.slot] = value
    }
  }
}
