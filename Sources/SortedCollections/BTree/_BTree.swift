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
  internal init(capacity: Int = BTREE_NODE_CAPACITY) {
    self.root = Node(isLeaf: false, withCapacity: capacity)
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
    var parents = [Path.ChildNode]()
    var node: Node? = self.root
    
    while let currentNode = node {
      let path: Path? = currentNode.read { handle in
        let keyIndex = handle.firstIndex(of: key)
        if keyIndex < handle.numKeys && handle[keyAt: keyIndex] == key {
          return Path(node: currentNode, slot: keyIndex, parents: parents)
        } else {
          if handle.isLeaf {
            node = nil
          } else {
            parents.append((node: currentNode, offset: keyIndex))
            node = handle[childAt: keyIndex]
          }
          
          return nil
        }
      }
      
      if let path = path {
        return path
      }
    }
    
    return nil
  }
}

// MARK: Write Operations
extension _BTree {
  /// Updates a B-Tree at a specific path, running uniqueness checks as it
  /// traverses the tree.
  @inlinable
  internal mutating func update(at path: Path, _ body: (Node.UnsafeHandle) -> Void) {
    var node = path.node
    node.update { body($0) }
    
    // Write back node to its parent and so on.
    for parent in path.parents.reversed() {
      var parentNode = parent.node
      parentNode.update { handle in
        handle[childAt: parent.offset] = node
      }
      node = parentNode
    }
    
    self.root = node
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
