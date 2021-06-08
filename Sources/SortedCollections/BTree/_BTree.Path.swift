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
  // TODO: potentially rename to 'UnsafePath' to clearly identify
  // the danger of not carefully handling paths.
  // TODO: (Alternative) Have _BTree issues paths within closures
  // which ensure that the _BTree lives as long as its paths.
  
  /// Represents a specific element in a BTree. This holds strong references to the
  /// element it points to.
  /// - Warning: Operations on this path will trap if the underlying node is deallocated.
  @usableFromInline
  struct Path {
    /// The position of each of the parent nodes in their parents. The path's depth
    /// is offsets.count + 1
    @usableFromInline
    internal var offsets: [Int] // TODO: potentially make compact (U)Int8/16 type to be more compact
    
    @usableFromInline
    internal unowned var node: Node.Storage
    
    @usableFromInline
    internal var slot: Int
    
    // MARK: Validation
    #if COLLECTIONS_INTERNAL_CHECKS
    @inline(never)
    @usableFromInline
    internal func validatePath() {
      precondition(slot >= 0, "Slot must be non-negative integer")
      precondition(Node(node).read { slot < $0.numElements }, "Slot must be within the node")
    }
    
    #else
    @inlinable
    @inline(__always)
    internal func validatePath() {}
    #endif // COLLECTIONS_INTERNAL_CHECKS
    
    
    // MARK: Path Initializers
    
    /// Creates a path representing a sequence of nodes to an element.
    /// - Parameters:
    ///   - node: The node to which this path points. 
    ///   - slot: The specific slot within node where the path points
    ///   - parents: The parent nodes and their children's offsets for this path.
    @inlinable
    internal init(node: Node, slot: Int, offsets: [Int]) {
      self.init(node: node.storage, slot: slot, offsets: offsets)
    }
    
    /// Creates a path representing a sequence of nodes to an element.
    /// - Parameters:
    ///   - node: The node to which this path points.
    ///   - slot: The specific slot within node where the path points
    ///   - parents: The parent nodes and their children's offsets for this path.
    @inlinable
    internal init(node: Node.Storage, slot: Int, offsets: [Int]) {
      self.node = node
      self.slot = slot
      self.offsets = offsets
      
      validatePath()
    }
    
    /// Gets the element the path points to.
    @inlinable
    @inline(__always)
    internal var element: Element {
      return Node(self.node).read { $0[elementAt: self.slot] }
    }
  }
}

// MARK: Equatable
extension _BTree.Path: Equatable {
  /// Returns true if two paths are identical (point to the same node).
  /// - Precondition: expects both paths are from the same BTree.
  /// - Complexity: O(1)
  @inlinable
  public static func ==(lhs: _BTree.Path, rhs: _BTree.Path) -> Bool {
    // We assume the parents are the same
    return lhs.node === rhs.node && lhs.slot == rhs.slot
  }
}

// MARK: Comparable
extension _BTree.Path: Comparable {
  /// Returns true if the first path points to an element before the second path
  /// - Complexity: O(`log n`)
  @inlinable
  public static func <(lhs: _BTree.Path, rhs: _BTree.Path) -> Bool {
    for i in 0..<min(lhs.offsets.count, rhs.offsets.count) {
      if lhs.offsets[i] < rhs.offsets[i] {
        return true
      }
    }
    
    if lhs.offsets.count < rhs.offsets.count {
      let rhsOffset = rhs.offsets[lhs.offsets.count - 1]
      return lhs.slot < rhsOffset
    } else if rhs.offsets.count < lhs.offsets.count {
      let lhsOffset = lhs.offsets[rhs.offsets.count - 1]
      return lhsOffset <= rhs.slot
    } else {
      return lhs.slot < rhs.slot
    }
  }
}
