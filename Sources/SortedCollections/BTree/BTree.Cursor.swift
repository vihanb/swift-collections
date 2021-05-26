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

extension BTree {
  @usableFromInline
  struct Cursor {
    @usableFromInline
    internal let root: Node<Key, Value>
  
    // TODO: consider whether the entire path of nodes should be stored.
    @usableFromInline
    internal let node: Node<Key, Value>
    
    // TODO: potentially use a fixed-size buffer to avoid
    // array overhead since the maximum height for tree with
    // N of order M is log(N)/log(M)+1. Meaning for an Int64,
    // (64-1) * (log(2)/log(N)) has an upper bound of ~63.
    /// Non-empty array representing the location of an element in a BTree
    @usableFromInline
    internal let path: [Int]
    
    /// Creates a cursor from the BTree root to the element. This does not
    /// perform any checks and assumes `node` is the correct node which
    /// results from traversing to `path` from the `root`.
    ///
    /// - Complexity: O(`log n`) worst case.
    @inlinable
    @inline(__always)
    internal init(root: Node<Key, Value>, node: Node<Key, Value>, path: [Int]) {
      self.root = root
      self.node = node
      self.path = path
    }
    
    /// Initializes a cursor with the BTree root and the path to the element.
    /// - Parameters:
    ///   - root: The BTree root
    ///   - path: Path from the root to the element
    /// - Complexity: O(`log n`) worst-case.
    @inlinable
    @inline(__always)
    internal init(root: Node<Key, Value>, path: [Int]) {
      self.root = root
      self.path = path
      
      var node = root
      
      for i in path.dropLast() {
        node = node.read { $0[childAt: i] }
      }
      
      self.node = node
    }
    
    /// Constructs a cursor to the first element of a BTree. For an
    /// empty BTree, this returns `nil` if the BTree is empty
    /// - Parameter btree: the non-empty BTree
    /// - Complexity: O(`log n`)
    @inlinable
    internal init?(firstElementOf btree: BTree) {
      // Cannot create a cursor for an empty tree.
      if btree.root.read({ $0.numKeys == 0 }) {
        return nil
      }
      
      self.root = btree.root
      
      var node = self.root
      var depth = 1
      while node.read({ $0.numChildren }) > 0 {
        node = node.read({ $0.children.pointee })
        depth += 1
      }
      
      self.node = node
      self.path = [Int](repeating: 0, count: depth)
    }
    
    /// Attempts to return an advanced copy of the cursor
    @inlinable
    @inline(__always)
    internal func advanced() -> Cursor? {
      // Try visiting each of the nodes if the exist.
      return self.rightChild ?? self.rightSibling ?? self.parent
    }
    
    // MARK: Tree-wise Cursor Movements
    @inlinable
    @inline(__always)
    internal var parent: Cursor? {
      guard self.path.count > 1 else { return nil }
      var newPath = self.path
      newPath.removeLast()
      // TODO: potentially also maintain the Node stack to avoid re-seeking the node
      // tradeoff is space-v-time.
      return Cursor(root: root, path: newPath)
    }
    
    
    @inlinable
    @inline(__always)
    internal var rightSibling: Cursor? {
      guard self.hasRightSibling else { return nil }
      var newPath = self.path
      newPath[newPath.count - 1] += 1
      return Cursor(root: root, node: node, path: newPath)
    }
    
    @inlinable
    @inline(__always)
    internal var leftChild: Cursor? {
      guard self.hasLeftChild else { return nil }
      var newPath = self.path
      newPath.append(0)
      // TODO: concern this is copying the node into the cursor. Desired?
      let newChild = node.read { $0[childAt: self.elementIndex] }
      return Cursor(root: root, node: newChild, path: newPath)
    }
    
    @inlinable
    @inline(__always)
    internal var rightChild: Cursor? {
      guard self.hasRightChild else { return nil }
      var newPath = self.path
      newPath[newPath.count - 1] += 1
      newPath.append(0)
      // TODO: concern this is copying the node into the cursor. Desired?
      let newChild = node.read { $0[childAt: self.elementIndex + 1] }
      return Cursor(root: root, node: newChild, path: newPath)
    }
    
    // MARK: Cursor Queries
    
    /// The index of the current element in it's node
    @inlinable
    @inline(__always)
    internal var elementIndex: Int { self.path[self.path.count - 1] }
    
    /// Checks if there is a sibling after the current cursor
    @inlinable
    @inline(__always)
    internal var hasRightSibling: Bool {
      self.node.read { self.elementIndex + 1 < $0.numKeys }
    }
    
    /// Checks if there is a left-child
    @inlinable
    @inline(__always)
    internal var hasLeftChild: Bool {
      self.node.read { self.elementIndex < $0.numChildren }
    }
    
    /// Checks if there is a right-child
    @inlinable
    @inline(__always)
    internal var hasRightChild: Bool {
      self.node.read { self.elementIndex + 1 < $0.numChildren }
    }
    
    /// Gets the element the cursor points to
    @inlinable
    @inline(__always)
    internal var element: Element {
      return self.node.read { $0[elementAt: self.elementIndex] }
    }
  }
}
