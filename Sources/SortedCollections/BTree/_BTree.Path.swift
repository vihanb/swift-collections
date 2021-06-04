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

// TODO: add 0 key validations
// TODO: potentially make operations mutating.

extension _BTree {
  /// Represents a specific element in a BTree. This holds strong references to the
  /// element it points to.
  @usableFromInline
  struct Path {
    @usableFromInline
    internal typealias ChildNode = (node: Node, offset: Int)
    
    @usableFromInline
    internal let parents: [ChildNode]
    
    @usableFromInline
    internal let node: _Node<Key, Value>
    
    @usableFromInline
    internal let slot: Int
    
    // MARK: Validation
    #if COLLECTIONS_INTERNAL_CHECKS
    @inline(never)
    @usableFromInline
    internal func validatePath() {
      precondition(slot >= 0, "Slot must be non-negative integer")
      precondition(node.read { slot < $0.numKeys }, "Slot must be within the node")
    }
    
    #else
    @inlinable
    @inline(__always)
    internal func validatePath() {}
    #endif // COLLECTIONS_INTERNAL_CHECKS
    
    
    // MARK: Path Initializers
    
    /// Creates a path representing a sequence of nodes to an element.
    /// - Parameters:
    ///   - node: The node to which this path points
    ///   - slot: The specific slot within node where the path points
    ///   - parents: The parent nodes and their children's offsets for this path.
    @inlinable
    internal init(node: Node, slot: Int, parents: [ChildNode]) {
      self.node = node
      self.slot = slot
      self.parents = parents
      
      validatePath()
    }
    
    /// Constructs a path to the first element of the BTree. For a
    /// BTree with no elements, this returns `nil`.
    /// - Parameter tree: the tree's elements.
    /// - Complexity: O(`log n`)
    @inlinable
    @inline(__always)
    internal init?(firstElementOf tree: _BTree) {
      self.init(firstElementOf: tree.root)
    }
    
    /// Constructs a path to the lowest element, beginning at
    /// a given path
    /// - Parameter path: A path to the element to traverse.
    /// - Complexity: O(`log n`)
    @inlinable
    @inline(__always)
    internal init?(firstElementOf path: Path) {
      self.init(firstElementOf: path.node, withPath: path)
    }

    
    /// Constructs a path to the first element of a node. For an
    /// empty node, this returns `nil` if the node is empty
    /// - Parameters:
    ///   - node: The node to get the first element of.
    ///   - parents: The preceeding parents.
    /// - Complexity: O(`log n`)
    @inlinable
    internal init?(firstElementOf node: Node, withPath path: Path? = nil) {
      // Cannot create a path to an element of a node with no keys
      if node.read({ $0.numKeys }) == 0 {
        return nil
      }
      
      var parents = path?.parents ?? []
      var node: Node = node
      var slot: Int = path?.slot ?? 0
      
      while node.read({ $0.numChildren }) > 0 {
        parents.append((node: node, offset: slot))
        node = node.read { $0[childAt: slot] }
        slot = 0
      }
      
      self.init(node: node, slot: slot, parents: parents)
    }
    
    /// Constructs a path to the element in the next-slot of the same node, to
    /// get the next element, use `Path#advanced()`. Returns `nil` when
    /// there is no next slot in the same node
    /// - Complexity: O(1)
    @inlinable
    @inline(__always)
    internal init?(slotAfter path: Path) {
      guard path.node.read({ path.slot < $0.numKeys - 1 }) else { return nil }
      self.init(node: path.node, slot: path.slot + 1, parents: path.parents)
    }
    
    /// Constructs the path pointing to the parent of another path. This
    /// returns `nil` if a parent does not exist
    /// - Complexity: O(1)
    @inlinable
    @inline(__always)
    internal init?(parentOf path: Path) {
      var newParents = path.parents
      guard let parentNode = newParents.popLast() else { return nil }
      self.init(node: parentNode.node, slot: parentNode.offset, parents: newParents)
    }
    
    /// Constructs the path to a node's right child. This returns
    /// `nil` if a right child does not exist.
    @inlinable
    @inline(__always)
    internal init?(rightChildOf path: Path) {
      var newParents = path.parents
      if path.node.read({ $0.isLeaf }) { return nil }
      newParents.append((node: path.node, offset: path.slot + 1))
      let rightChild = path.node.read({ $0[childAt: path.slot + 1] })
      self.init(node: rightChild, slot: 0, parents: newParents)
    }
    
    /// Advances the cursor to sequentially next element in the BTree.
    /// - Returns: A new path to the next element. Nil if there is no
    /// next element.
    @inlinable
    @inline(__always)
    internal func advanced() -> Path? {
      // Try visiting each of the nodes if the exist.
      node.read { handle in
        if handle.isLeaf {
          if let nextElementPath = Path(slotAfter: self) {
            return nextElementPath
          } else {
            var nextParent = Path(parentOf: self)
            while let parentPath = nextParent, parentPath.isLastSlot {
              nextParent = Path(parentOf: parentPath)
            }
            
            if let ancestor = nextParent {
              return Path(slotAfter: ancestor)
            } else {
              return nil
            }
          }
        } else {
          return Path(firstElementOf: Path(rightChildOf: self)!)
        }
      }
    }
    
    // MARK: Path Operations
    @inlinable
    @inline(__always)
    internal var isLastSlot: Bool { node.read { slot == $0.numKeys - 1 } }
    
    // MARK: Tree-wise Cursor Movements
    /// Gets the element the cursor points to
    @inlinable
    @inline(__always)
    internal var element: Element {
      return self.node.read { $0[elementAt: self.slot] }
    }
  }
}

// MARK: Equatable
extension _BTree.Path: Equatable {
  /// Returns true if two paths are identical (point to the same node).
  /// - Precondition: expects both paths are from the same tree at the
  ///     same state of time.
  /// - Complexity: O(`min(lhs.depth, rhs.depth)`)
  @inlinable
  public static func ==(lhs: _BTree.Path, rhs: _BTree.Path) -> Bool {
    // We assume the parents are the same
    return lhs.node == rhs.node && lhs.slot == rhs.slot
  }
}

// MARK: Comparable
extension _BTree.Path: Comparable {
  /// Returns true if the first path points to an element before the second path
  @inlinable
  public static func <(lhs: _BTree.Path, rhs: _BTree.Path) -> Bool {
    for i in 0..<min(lhs.parents.count, rhs.parents.count) {
      if lhs.parents[i].offset < rhs.parents[i].offset {
        return true
      }
    }
    
    if lhs.parents.count < rhs.parents.count {
      let rhsOffset = rhs.parents[lhs.parents.count - 1].offset
      return lhs.slot < rhsOffset
    } else if rhs.parents.count < lhs.parents.count {
      let lhsOffset = lhs.parents[rhs.parents.count - 1].offset
      return lhsOffset <= rhs.slot
    } else {
      return lhs.slot < rhs.slot
    }
  }
}
