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

// TODO: decide node capacity. Currently exploring 470 v 1050
// TODO: better benchmarking here

/// Internal node capacity for BTree
@usableFromInline
internal let BTREE_INTERNAL_CAPACITY = 16

/// Leaf node capacity for BTree
@usableFromInline
internal let BTREE_LEAF_CAPACITY = 470

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
  
  // TODO: remove
  /// The capacity of each of the internal nodes
  @usableFromInline
  internal var internalCapacity: Int
  
  /// Creates an empty BTree rooted at a specific node with a specified uniform capacity
  /// - Parameter capacity: The key capacity of all nodes.
  @inlinable
  @inline(__always)
  internal init(capacity: Int) {
    self.init(leafCapacity: capacity, internalCapacity: capacity)
  }
  
  /// Creates an empty BTree which creates node with specified capacities
  /// - Parameters:
  ///   - leafCapacity: The capacity of the leaf nodes. This is the initial buffer used to allocate.
  ///   - internalCapacity: The capacity of the internal nodes. Generally prefered to be less than `leafCapacity`.
  @inlinable
  @inline(__always)
  internal init(leafCapacity: Int = BTREE_LEAF_CAPACITY, internalCapacity: Int = BTREE_INTERNAL_CAPACITY) {
    self.init(rootedAt: Node(withCapacity: leafCapacity, isLeaf: true), leafCapacity: leafCapacity, internalCapacity: internalCapacity)
  }
  
  /// Creates a BTree rooted at a specific node with a specified uniform capacity
  /// - Parameters:
  ///   - root: The root node.
  ///   - capacity: The key capacity of all nodes.
  @inlinable
  @inline(__always)
  internal init(rootedAt root: Node, capacity: Int) {
    self.init(rootedAt: root, leafCapacity: capacity, internalCapacity: capacity)
  }
  
  /// Creates a BTree rooted at a specific node.
  /// - Parameters:
  ///   - root: The root node.
  ///   - leafCapacity: The capacity of the leaf nodes. This is the initial buffer used to allocate.
  ///   - internalCapacity: The capacity of the internal nodes. Generally prefered to be less than `leafCapacity`.
  @inlinable
  @inline(__always)
  internal init(rootedAt root: Node, leafCapacity: Int = BTREE_LEAF_CAPACITY, internalCapacity: Int = BTREE_INTERNAL_CAPACITY) {
    self.root = root
    self.internalCapacity = internalCapacity
  }
}

// MARK: Mutating Operations
extension _BTree {
  @usableFromInline
  internal enum InsertionResult {
    case updated(previousValue: Value)
    case splintered(Node.Splinter)
    case inserted
    
    @inlinable
    @inline(__always)
    internal init(from splinter: Node.Splinter?) {
      if let splinter = splinter {
        self = .splintered(splinter)
      } else {
        self = .inserted
      }
    }
  }
  
  @usableFromInline
  internal enum KeyPosition {
    case start
    case end
    
    @usableFromInline
    func insertionIndex(for key: Key, in handle: Node.UnsafeHandle) -> Int {
      switch self {
      case .start:
        return handle.firstIndex(of: key)
      case .end:
        return handle.lastIndex(of: key)
      }
    }
  }
  
  // TODO: potentially remove
  /// Runs a function on a given key and bubbles the result back up
  @inlinable
  @inline(__always)
  internal mutating func updateKey<R>(
    _ key: Key,
    at position: KeyPosition,
    bubble: (R, Node.UnsafeHandle) -> R,
    operation: (Node.UnsafeHandle, Int) -> R
  ) -> R {
    func processLayer(_ handle: Node.UnsafeHandle) -> R {
      let insertionIndex = position.insertionIndex(for: key, in: handle)
      
      // See if we found the element early
      // TODO: this does not properly handle duplicates
      if _slowPath(insertionIndex > 0 &&
          handle[keyAt: insertionIndex - 1] == key) {
        return operation(handle, insertionIndex - 1)
      }
      
      if handle.isLeaf {
        return operation(handle, insertionIndex)
      } else {
        let childResult = handle[childAt: insertionIndex].update({ processLayer($0) })
        return bubble(childResult, handle)
      }
    }
    
    return self.root.update { processLayer($0) }
  }
  
  /// Inserts an element into the BTree, or updates it if it already exists within the tree. If there are
  /// multiple instances of the key in the tree, this updates the last one.
  ///
  /// - Parameters:
  ///   - element: The key-value pair to insert
  /// - Returns: If updated, the previous value for the key.
  /// - Complexity: O(`log n`)
  @inlinable
  @discardableResult
  internal mutating func insertOrUpdate(_ element: Element) -> Value? {
    // TODO: this is not needed for BTrees without duplicates
    // Potentially add a flag to not perform unneeded descents.
    func findLast(within handle: Node.UnsafeHandle, at index: Int) -> Value? {
      if _slowPath(index > 0 && handle[keyAt: index - 1] == element.key) {
        let updateIndex = index - 1
        
        if !handle.isLeaf {
          let previousValue: Value? = handle[childAt: updateIndex].update { handle in
            let index = handle.lastIndex(of: element.key)
            return findLast(within: handle, at: index)
          }
          
          if let previousValue = previousValue {
            return previousValue
          }
        }
        
        let previousValue = handle.values.advanced(by: updateIndex).move()
        handle.values.advanced(by: updateIndex).initialize(to: element.value)
        return previousValue
      } else {
        return nil
      }
    }
    
    func insertInto(node handle: Node.UnsafeHandle) -> InsertionResult {
      let insertionIndex = handle.lastIndex(of: element.key)
      
      if let previousValue = findLast(within: handle, at: insertionIndex) {
        return .updated(previousValue: previousValue)
      }
      
      // We need to try to insert as deep as possible as first, and have the splinter
      // bubble up.
      if handle.isLeaf {
        let maybeSplinter = handle.immediatelyInsert(element: element, withRightChild: nil, at: insertionIndex)
        return InsertionResult(from: maybeSplinter)
      } else {
        let result = handle[childAt: insertionIndex].update({ handle in
          insertInto(node: handle)
        })
        
        switch result {
        case .updated:
          return result
        case .splintered(let splinter):
          let maybeSplinter = handle.immediatelyInsert(splinter: splinter, at: insertionIndex)
          return InsertionResult(from: maybeSplinter)
        case .inserted:
          handle.numTotalElements += 1
          return .inserted
        }
      }
    }
    
    let result = self.root.update { insertInto(node: $0) }
    switch result {
    case let .updated(previousValue):
      return previousValue
    case let .splintered(splinter):
      self.root = splinter.toNode(from: self.root, withCapacity: self.internalCapacity)
    default: break
    }
    
    return nil
  }
}

// MARK: Read Operations
extension _BTree {
  /// Returns a path to the key at absolute offset `i`.
  /// - Parameter offset: 0-indexed offset within BTree bounds, else may panic.
  /// - Returns: the index of the appropriate element.
  /// - Complexity: O(`log n`)
  @inlinable
  internal func indexToElement(at offset: Int) -> Index {
    assert(offset <= self.count, "Index out of bounds.")
    
    if offset == self.count {
      return Index(nil)
    }
    
    var offsets = [Int]()
    offsets.reserveCapacity(BTREE_MAX_DEPTH)
    
    var node: _Node = self.root
    var startIndex = 0
    
    while !node.read({ $0.isLeaf }) {
      let internalPath: UnsafePath? = node.read { handle in
        for childSlot in 0..<handle.numChildren {
          let child = handle[childAt: childSlot]
          let endIndex = startIndex + child.read({ $0.numTotalElements })
          
          if offset < endIndex {
            offsets.append(childSlot)
            node = child
            return nil
          } else if offset == endIndex {
            // We've found the node we want
            return UnsafePath(node: node, slot: childSlot, offsets: offsets, index: offset)
          } else {
            startIndex = endIndex + 1
          }
        }
        
        // TODO: convert into debug-only preconditionFaliure
        preconditionFailure("In-bounds index not found within tree.")
      }
      
      if let internalPath = internalPath { return Index(internalPath) }
    }
    
    return Index(UnsafePath(node: node, slot: offset - startIndex, offsets: offsets, index: offset))
  }
  
  /// Returns the value corresponding to the first instance of the key
  /// - Complexity: O(`log n`)
  @inlinable
  internal func firstValue(for key: Key) -> Value? {
    // TODO: check if switching to unowned storage removes
    // the retain/release calls
    // Retain
    var node: Node? = self.root
    
    while let currentNode = node {
      let value: Value? = currentNode.read { handle in
        let index = handle.firstIndex(of: key)
        
        if index < handle.numElements && handle[keyAt: index] == key {
          return handle[valueAt: index]
        } else {
          if handle.isLeaf {
            node = nil
          } else {
            // Release
            // Retain
            node = handle[childAt: index]
          }
        }
        
        return nil
      }
      
      if let value = value { return value }
    }
    
    return nil
  }
  
  /// Returns a path to the first key that is equal to given key.
  /// - Returns: If found, returns a cursor to the element.
  @inlinable
  internal func findFirstKey(_ key: Key) -> UnsafePath? {
    var offsets = [Int]()
    var node: Node? = self.root
    
    while let currentNode = node {
      let path: UnsafePath? = currentNode.read { handle in
        let keyIndex = handle.firstIndex(of: key)
        if keyIndex < handle.numElements && handle[keyAt: keyIndex] == key {
          return UnsafePath(node: currentNode.storage, slot: keyIndex, offsets: offsets, index: 0)
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
