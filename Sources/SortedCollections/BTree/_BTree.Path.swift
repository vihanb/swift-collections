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

extension _BTree {
  /// Represents a specific element in a BTree. This holds strong references to the
  /// element it points to.
  @usableFromInline
  struct Path {
    @usableFromInline
    typealias ChildNode = (node: Node, offset: Int)
    
    @usableFromInline
    internal let parents: [ChildNode]
    
    @usableFromInline
    internal let node: _Node<Key, Value>
    
    @usableFromInline
    internal let slot: Int
    
    @inlinable
    internal init(node: Node, slot: Int, parents: [ChildNode]) {
      self.node = node
      self.slot = slot
      self.parents = parents
    }
    
    @inlinable
    @inline(__always)
    internal init?(firstElementOf tree: _BTree) {
      self.init(firstElementOf: tree.root)
    }
    
    /// Constructs a cursor to the first element of a node. For an
    /// empty node, this returns `nil` if the node is empty
    /// - Parameter btree: the non-empty node
    /// - Complexity: O(`log n`)
    @inlinable
    internal init?(firstElementOf node: Node, parents: [ChildNode] = []) {
      // Cannot create a path to an element of a node with no keys
      if node.read({ $0.numKeys }) == 0 {
        return nil
      }
      
      var parents = parents
      var node: Node = node
      
      while node.read({ $0.numChildren }) > 0 {
        parents.append((node: node, offset: 0))
        node = node.read { $0[childAt: 0] }
      }
      
      self.init(node: node, slot: 0, parents: parents)
    }
    
    /// Attempts to return an advanced copy of the cursor
    @inlinable
    @inline(__always)
    internal func advanced() -> Path? {
      // Try visiting each of the nodes if the exist.
      return nil
    }
    
    // MARK: Tree-wise Cursor Movements
//    @inlinable
//    @inline(__always)
//    internal var parent: Path? {
//      guard self.path.count > 1 else { return nil }
//      var newPath = self.path
//      newPath.removeLast()
//      // TODO: potentially also maintain the Node stack to avoid re-seeking the node
//      // tradeoff is space-v-time.
//      return Path(root: root, path: newPath)
//    }
//
//
//    @inlinable
//    @inline(__always)
//    internal var rightSibling: Path? {
//      guard self.hasRightSibling else { return nil }
//      var newPath = self.path
//      newPath[newPath.count - 1] += 1
//      return Path(root: root, node: node, path: newPath)
//    }
//
//    @inlinable
//    @inline(__always)
//    internal var leftChild: Path? {
//      guard self.hasLeftChild else { return nil }
//      var newPath = self.path
//      newPath.append(0)
//      // TODO: concern this is copying the node into the cursor. Desired?
//      let newChild = node.read { $0[childAt: self.elementSlot] }
//      return Path(root: root, node: newChild, path: newPath)
//    }
//
//    @inlinable
//    @inline(__always)
//    internal var rightChild: Path? {
//      guard self.hasRightChild else { return nil }
//      var newPath = self.path
//      newPath[newPath.count - 1] += 1
//      newPath.append(0)
//      // TODO: concern this is copying the node into the cursor. Desired?
//      let newChild = node.read { $0[childAt: self.elementSlot + 1] }
//      return Path(root: root, node: newChild, path: newPath)
//    }
//
//    // MARK: Cursor Queries
//
//    /// Checks if there is a sibling after the current cursor
//    @inlinable
//    @inline(__always)
//    internal var hasRightSibling: Bool {
//      self.node.read { self.elementSlot + 1 < $0.numKeys }
//    }
//
//    /// Checks if there is a left-child
//    @inlinable
//    @inline(__always)
//    internal var hasLeftChild: Bool {
//      self.node.read { self.elementSlot < $0.numChildren }
//    }
//
//    /// Checks if there is a right-child
//    @inlinable
//    @inline(__always)
//    internal var hasRightChild: Bool {
//      self.node.read { self.elementSlot + 1 < $0.numChildren }
//    }
//
    /// Gets the element the cursor points to
    @inlinable
    @inline(__always)
    internal var element: Element {
      return self.node.read { $0[elementAt: self.slot] }
    }
  }
}
