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

/// A bidirectional collection representing a BTree which efficiently stores its
/// elements in sorted order and maintains roughly `O(log count)`
/// performance for most operations.
///
/// - Warning: Indexing operations on a BTree are unchecked. ``_BTree.Index``
///   offers `ensureValid(for:)` methods to validate indices for use in higher-level
///   collections.
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
  
  /// A metric to uniquely identify a given BTree's state. It is not
  /// impossible for two BTrees to have the same age by pure
  /// coincidence.
  @usableFromInline
  internal var age: Int32
  
  /// Creates an empty BTree rooted at a specific node with a specified uniform capacity
  /// - Parameter capacity: The key capacity of all nodes.
  @inlinable
  @inline(__always)
  internal init(capacity: Int) {
    self.init(
      leafCapacity: capacity,
      internalCapacity: capacity
    )
  }
  
  /// Creates an empty BTree which creates node with specified capacities
  /// - Parameters:
  ///   - leafCapacity: The capacity of the leaf nodes. This is the initial buffer used to allocate.
  ///   - internalCapacity: The capacity of the internal nodes. Generally prefered to be less than `leafCapacity`.
  @inlinable
  @inline(__always)
  internal init(leafCapacity: Int = BTREE_LEAF_CAPACITY, internalCapacity: Int = BTREE_INTERNAL_CAPACITY) {
    self.init(
      rootedAt: Node(withCapacity: leafCapacity, isLeaf: true),
      leafCapacity: leafCapacity,
      internalCapacity: internalCapacity
    )
  }
  
  /// Creates a BTree rooted at a specific node with a specified uniform capacity
  /// - Parameters:
  ///   - root: The root node.
  ///   - capacity: The key capacity of all nodes.
  @inlinable
  @inline(__always)
  internal init(rootedAt root: Node, capacity: Int) {
    self.init(
      rootedAt: root,
      leafCapacity: capacity,
      internalCapacity: capacity
    )
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
    self.age = Int32(truncatingIfNeeded: ObjectIdentifier(root.storage).hashValue)
  }
}

// MARK: Mutating Operations
extension _BTree {
  /// Invalidates the issued indices of the dictionary. Ensure this is
  /// called for operations which mutate the SortedDictionary.
  @inlinable
  @inline(__always)
  internal mutating func invalidateIndices() {
    self.age &+= 1
  }
  
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
    invalidateIndices()
    
    // TODO: this is not needed for BTrees without duplicates
    // Potentially add a flag to not perform unneeded descents.
    func findLast(within handle: Node.UnsafeHandle, at index: Int) -> Value? {
      if _slowPath(index > 0 && handle[keyAt: index - 1] == element.key) {
        let updateIndex = index - 1
        
        if !handle.isLeaf {
          let previousValue: Value? = handle[childAt: updateIndex].update { handle in
            let index = handle.lastSlot(for: element.key)
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
      let insertionIndex = handle.lastSlot(for: element.key)
      
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
  
  /// Removes the key-value pair corresponding to the first found instance of the key.
  /// This may not be the first instance of the key. This is marginally more efficient for trees
  /// that do not have duplicates.
  ///
  /// If the key is not found, the tree is not modified, although the age of the tree may change.
  ///
  /// - Parameter key: The key to remove in the tree
  /// - Returns: The key-value pair which was removed. `nil` if not removed.
  @inlinable
  @discardableResult
  internal mutating func removeAny(key: Key) -> Element? {
    invalidateIndices()
    
    return nil
  }
}

// MARK: Read Operations
extension _BTree {  
  /// Returns the value corresponding to the first found instance of the key. This may
  /// not be the first instance of the key. This is marginally more efficient for trees
  /// that do not have duplicates.
  ///
  /// - Parameter key: The key to search for
  /// - Returns: `nil` if the key was not found. Otherwise, the previous value.
  /// - Complexity: O(`log n`)
  @inlinable
  internal func anyValue(for key: Key) -> Value? {
    // the retain/release calls
    // Retain
    var node: Unmanaged<Node.Storage>? = .passUnretained(self.root.storage)
    
    while node != nil {
      // Retain(node)
      let value: Value? = node.unsafelyUnwrapped._withUnsafeGuaranteedRef { storage in
        unsafeBitCast(storage, to: Node.self).read { handle in
          let slot = handle.firstSlot(for: key)
          
          if slot < handle.numElements && handle[keyAt: slot] == key {
            return handle[valueAt: slot]
          } else {
            if handle.isLeaf {
              // Release(node)
              node = nil
            } else {
              // Release(node)
              let nextNode: Unmanaged<Node.Storage> = .passUnretained(handle[childAt: slot].storage)
              node = nextNode
            }
          }
          
          return nil
        }
      }
      
      if let value = value { return value }
    }
    
    return nil
  }
}
