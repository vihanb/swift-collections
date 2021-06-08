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

/// Totally arbitrary node capacity for BTree
@usableFromInline
internal let BTREE_NODE_CAPACITY = 3

/// An expected rough upper bound for BTree depth
@usableFromInline
internal let BTREE_MAX_DEPTH = 10

@usableFromInline
internal struct _BTree<Key: Comparable, Value> {
  @usableFromInline
  typealias Element = (key: Key, value: Value)
  
  @usableFromInline
  typealias Node = _Node<Key, Value>
  
  /// The underlying node behind this local BTree
  @usableFromInline
  internal var root: Node
  
  /// Represents the path to the start index.
  /// - Warning: This is not a valid path when the BTree is empty.
  @usableFromInline
  internal var startPath: Path
  
  // TODO: remove
  @usableFromInline
  internal var capacity: Int
  
  @inlinable
  @inline(__always)
  internal init(capacity: Int = BTREE_NODE_CAPACITY) {
    self.init(rootedAt: Node(withCapacity: capacity, isLeaf: true), capacity: capacity)
  }
  
  @inlinable
  @inline(__always)
  internal init(rootedAt root: Node, capacity: Int = BTREE_NODE_CAPACITY) {
    assert(root.read({ $0.isLeaf }), "Constructing BTree rooted at non-leaf Node.")
    self.root = root
    self.capacity = capacity
    
    self.startPath = Path(node: self.root, slot: 0, offsets: [], index: 0)
    self.startPath.offsets.reserveCapacity(BTREE_MAX_DEPTH)
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
      self.startPath.offsets.append(0)
    }
  }
}

// MARK: Write Operations
extension _BTree {
  /// Updates a B-Tree at a specific path, running uniqueness checks as it
  /// traverses the tree.
  @inlinable
  internal mutating func update<R>(at path: Path, _ body: (Node.UnsafeHandle) -> R) -> R {
    // TODO: get away from this recursion
    func update(_ handle: Node.UnsafeHandle, depth: Int) -> R {
      if depth == path.offsets.count {
        return body(handle)
      } else {
        let offset = path.offsets[depth]
        return handle[childAt: offset].update { update($0, depth: depth + 1) }
      }
    }
    
    return self.root.update { update($0, depth: 0) }
  }
  
  /// Updates the corresponding value for a key in the tree.
  /// - Parameters:
  ///   - value: New value for the key.
  ///   - path: A valid path within the tree
  /// - Returns: The old value, if replaced.
  /// - Complexity: O(1)
  @discardableResult
  @inlinable
  internal mutating func setValue(_ value: Value, at path: Path) -> Value {
    // TODO: this involves two tree descents. One to find the key, another
    // to run the update
    return self.update(at: path) { handle in
      let oldValue = handle[valueAt: path.slot]
      handle[valueAt: path.slot] = value
      return oldValue
    }
  }
}

// MARK: Read Operations
extension _BTree {
  /// Returns a path to the key at absolute offset `i`.
  /// - Parameter offset: 0-indexed offset within BTree bounds, else may panic.
  /// - Returns: the path to the appropriate element.
  @inlinable
  internal func pathToElement(at offset: Int) -> Path {
    assert(offset < self.count, "Index out of bounds.")
    
    var offsets = [Int]()
    
    var node: _Node = self.root
    var startIndex = 0
    
    while !node.read({ $0.isLeaf }) {
      let internalPath: Path? = node.read { handle in
        for childSlot in 0..<handle.numChildren {
          let child = handle[childAt: childSlot]
          let endIndex = startIndex + child.read({ $0.numTotalElements })
          
          if offset < endIndex {
            offsets.append(childSlot)
            node = child
            return nil
          } else if offset == endIndex {
            // We've found the node we want
            return Path(node: node, slot: childSlot, offsets: offsets, index: offset)
          } else {
            startIndex = endIndex + 1
          }
        }
        
        preconditionFailure("In-bounds index not found within tree.")
      }
      
      if let internalPath = internalPath { return internalPath }
    }
    
    return Path(node: node, slot: offset - startIndex, offsets: offsets, index: offset)
  }
  
  /// Returns a path to the first key that is equal to given key.
  /// - Returns: If found, returns a cursor to the element.
  @inlinable
  internal func findFirstKey(_ key: Key) -> Path? {
    var offsets = [Int]()
    var node: Node? = self.root
    
    while let currentNode = node {
      let path: Path? = currentNode.read { handle in
        let keyIndex = handle.firstIndex(of: key)
        if keyIndex < handle.numElements && handle[keyAt: keyIndex] == key {
          return Path(node: currentNode.storage, slot: keyIndex, offsets: offsets, index: 0)
        } else {
          if handle.isLeaf {
            node = nil
          } else {
            offsets.append(keyIndex)
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
