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

extension _Node {
  @usableFromInline
  internal struct UnsafeHandle {
    @usableFromInline
    internal let header: UnsafeMutablePointer<Header>
    
    @usableFromInline
    internal let keys: UnsafeMutablePointer<Key>
    
    @usableFromInline
    internal let values: UnsafeMutablePointer<Value>
    
    @usableFromInline
    internal let children: UnsafeMutablePointer<_Node<Key, Value>>?
    
    @inlinable
    @inline(__always)
    internal init(
      keys: UnsafeMutablePointer<Key>,
      values: UnsafeMutablePointer<Value>,
      children: UnsafeMutablePointer<_Node<Key, Value>>?,
      header: UnsafeMutablePointer<Header>,
      isMutable: Bool
    ) {
      self.keys = keys
      self.values = values
      self.children = children
      self.header = header
      
      #if COLLECTIONS_INTERNAL_CHECKS
      self.isMutable = isMutable
      #endif
    }
    
    // MARK: Mutablility Checks
    #if COLLECTIONS_INTERNAL_CHECKS
    @usableFromInline
    internal let isMutable: Bool
    #endif
    
    /// Check that this handle supports mutating operations.
    /// Every member that mutates node data must start by calling this function.
    /// This helps preventing COW violations.
    ///
    /// Note that this is a noop in release builds.
    @inlinable
    @inline(__always)
    internal func assertMutable() {
      #if COLLECTIONS_INTERNAL_CHECKS
      assert(self.isMutable, "Attempt to mutate a node through a read-only handle")
      #endif
    }
    
    // MARK: Invariant Checks
    #if COLLECTIONS_INTERNAL_CHECKS
    @inline(never)
    @usableFromInline
    internal func checkInvariants() {
      assert(isLeaf || numChildren == numElements + 1, "Node must have either zero children or a child on the side of each key.")
      assert(numElements == numElements, "Node must have equal count of keys and values ")
      assert(numElements >= 0, "Node cannot have negative number of elements")
      assert(numTotalElements >= numElements, "Total number of elements under node cannot be less than the number of immediate elements.")
      
      if numElements > 1 {
        for i in 0..<(numElements - 1) {
          precondition(self[keyAt: i] <= self[keyAt: i + 1], "Node is out-of-order.")
        }
      }
      
      if !isLeaf && false {
        for i in 0..<numElements {
          let key = self[keyAt: i]
          let child = self[childAt: i].read({ $0[keyAt: $0.numElements - 1] })
          precondition(child <= key, "Left subtree must be less or equal to than its parent key.")
        }
        
        let key = self[keyAt: numElements - 1]
        let child = self[childAt: numElements].read({ $0[keyAt: $0.numElements - 1] })
        precondition(child >= key, "Right subtree must be greater than or equal to than its parent key.")
      }
    }
    #else
    @inlinable
    @inline(__always)
    internal func checkInvariants() {}
    #endif // COLLECTIONS_INTERNAL_CHECKS
    
    /// Creates a mutable version of this handle
    @inlinable
    @inline(__always)
    internal init(mutableCopyOf handle: UnsafeHandle) {
      self.init(
        keys: handle.keys,
        values: handle.values,
        children: handle.children,
        header: handle.header,
        isMutable: true
      )
    }
    
    // MARK: Convenience properties
    @inlinable
    @inline(__always)
    internal var capacity: Int { header.pointee.capacity }
    
    /// The number of elements immediately stored in the node
    @inlinable
    @inline(__always)
    internal var numElements: Int {
      get { header.pointee.count }
      nonmutating set { assertMutable(); header.pointee.count = newValue }
    }
    
    /// The total number of elements that this node directly or indirectly stores
    @inlinable
    @inline(__always)
    internal var numTotalElements: Int {
      get { header.pointee.totalElements }
      nonmutating set { assertMutable(); header.pointee.totalElements = newValue }
    }
    
    /// The number of children this node directly contains
    @inlinable
    @inline(__always)
    internal var numChildren: Int { self.isLeaf ? 0 : self.numElements + 1 }
    
    // TODO: determine whether this is true or false more often than not.
    @inlinable
    @inline(__always)
    internal var isLeaf: Bool { children == nil }
  }
}

// MARK: Subscript
extension _Node.UnsafeHandle {
  @inlinable
  @inline(__always)
  internal subscript(elementAt index: Int) -> _Node.Element {
    get {
      assert(index < self.numElements, "Node element subscript out of bounds.")
      return (key: self.keys[index], value: self.values[index])
    }
    
    nonmutating set(newElement) {
      assertMutable()
      assert(index < self.numElements, "Node element subscript out of bounds.")
      
      // TODO: ensure that the subscript does deintialize the old
      // element
      self.keys[index] = newElement.key
      self.values[index] = newElement.value
    }
  }
  
  @inlinable
  @inline(__always)
  internal subscript(keyAt index: Int) -> Key {
    get {
      assert(index < self.numElements, "Node key subscript out of bounds.")
      return self.keys[index]
    }
  }
  
  @inlinable
  @inline(__always)
  internal subscript(valueAt index: Int) -> Value {
    get {
      assert(index < self.numElements, "Node values subscript out of bounds.")
      return self.values[index]
    }
  }
  
  // TODO: consider implementing `_modify` for these subscripts
  @inlinable
  @inline(__always)
  internal subscript(childAt index: Int) -> _Node {
    get {
      assert(index < self.numChildren, "Node child subscript out of bounds")
      assert(!isLeaf, "Cannot access children of leaf node.")
      return self.children.unsafelyUnwrapped[index]
    }
    
    nonmutating _modify {
      assert(!isLeaf, "Cannot modify children of leaf node.")
      var child = self.children.unsafelyUnwrapped.advanced(by: index).move()
      defer { self.children.unsafelyUnwrapped.advanced(by: index).initialize(to: child) }
      yield &child
    }
  }
}

// MARK: Binary Search
extension _Node.UnsafeHandle {
  /// Performs O(log n) search for a key, returning the first instance when duplicates exist. This
  /// returns the first possible insertion point for `key`.
  @usableFromInline
  internal func firstIndex(of key: Key) -> Int {
    var start: Int = 0
    var end: Int = self.numElements
    
    while end > start {
      let mid = (end - start) / 2 + start
      
      if key <= self.keys[mid] {
        end = mid
      } else {
        start = mid + 1
      }
    }
    
    return end
  }
  
  /// Performs O(log n) search for a key, returning the last instance when duplicates exist. This
  /// returns the last possible valid insertion point for `key`.
  @usableFromInline
  internal func lastIndex(of key: Key) -> Int {
    var start: Int = 0
    var end: Int = self.numElements
    
    while end > start {
      let mid = (end - start) / 2 + start
      
      if key >= self.keys[mid] {
        start = mid + 1
      } else {
        end = mid
      }
    }
    
    return end
  }
}

// MARK: Element-wise Buffer Operations
extension _Node.UnsafeHandle {
  /// Moves elements from the current handle to a new handle
  /// - Parameters:
  ///   - newHandle: The destination handle to write to which could be the same
  ///       as the source to move within a handle.
  ///   - sourceIndex: The offset of the source handle to move from.
  ///   - destinationIndex: The offset of the destintion handle to write to.
  ///   - count: The amount of values to move
  /// - Warning: This does not adjust the buffer counts.
  @inlinable
  @inline(__always)
  internal func moveElements(
    toHandle newHandle: _Node.UnsafeHandle,
    fromIndex sourceIndex: Int,
    toIndex destinationIndex: Int,
    count: Int
  ) {
    assert(sourceIndex >= 0, "Move source index must be positive.")
    assert(destinationIndex >= 0, "Move destination index must be positive.")
    assert(count >= 0, "Amount of elements to move be positive.")
    assert(sourceIndex + count <= self.capacity, "Cannot move elements beyond source buffer capacity.")
    assert(destinationIndex + count <= newHandle.capacity, "Cannot move elements beyond destination buffer capacity.")
    
    self.assertMutable()
    newHandle.assertMutable()
    
    newHandle.keys.advanced(by: destinationIndex)
      .moveInitialize(from: self.keys.advanced(by: sourceIndex), count: count)
    
    newHandle.values.advanced(by: destinationIndex)
      .moveInitialize(from: self.values.advanced(by: sourceIndex), count: count)
  }
  
  /// Moves children from the current handle to a new handle
  /// - Parameters:
  ///   - newHandle: The destination handle to write to which could be the same
  ///       as the source to move within a handle.
  ///   - sourceIndex: The offset of the source handle to move from.
  ///   - destinationIndex: The offset of the destintion handle to write to.
  ///   - count: The amount of values to move
  /// - Warning: This does not adjust the buffer counts.
  @inlinable
  @inline(__always)
  internal func moveChildren(
    toHandle newHandle: _Node.UnsafeHandle,
    fromIndex sourceIndex: Int,
    toIndex destinationIndex: Int,
    count: Int
  ) {
    assert(sourceIndex >= 0, "Move source index must be positive.")
    assert(destinationIndex >= 0, "Move destination index must be positive.")
    assert(count >= 0, "Amount of children to move be positive.")
    assert(sourceIndex + count <= self.capacity + 1, "Cannot move children beyond source buffer capacity.")
    assert(destinationIndex + count <= newHandle.capacity + 1, "Cannot move children beyond destination buffer capacity.")
    assert(!newHandle.isLeaf, "Cannot move children to a leaf node")
    assert(!self.isLeaf, "Cannot move chidlren from a leaf node")
    
    self.assertMutable()
    newHandle.assertMutable()
    
    newHandle.children.unsafelyUnwrapped.advanced(by: destinationIndex)
      .moveInitialize(from: self.children.unsafelyUnwrapped.advanced(by: sourceIndex), count: count)
  }
  
  /// Inserts a new element somewhere into the handle.
  /// - Parameters:
  ///   - element: The element to insert which the node will take ownership of.
  ///   - index: An uninitialized index in the buffer to insert the element into.
  /// - Warning: This does not adjust the buffer counts.
  @inlinable
  @inline(__always)
  internal func setElement(_ element: _Node.Element, withRightChild rightChild: _Node?, at index: Int) {
    assertMutable()
    assert(index < self.capacity, "Cannot insert beyond node capacity.")
    assert(self.isLeaf == (rightChild == nil), "A child can only be inserted iff the node is a leaf.")
    
    self.keys.advanced(by: index).initialize(to: element.key)
    self.values.advanced(by: index).initialize(to: element.value)
    
    if let rightChild = rightChild {
      self.children.unsafelyUnwrapped.advanced(by: index + 1).initialize(to: rightChild)
    }
  }
  
  /// Moves an element out of the handle
  /// - Parameter index: The in-bounds index of an element to move out
  /// - Returns: A tuple of the key and value.
  /// - Warning: This does not adjust buffer counts
  @inlinable
  @inline(__always)
  internal func moveElement(at index: Int) -> _Node.Element {
    assertMutable()
    assert(index < self.numElements, "Attempted to move out-of-bounds element.")
    
    return (
      key: self.keys.advanced(by: index).move(),
      value: self.values.advanced(by: index).move()
    )
  }
  
  /// Recomputes the total amount of elements in two nodes.
  @inlinable
  @inline(__always)
  internal func recomputeTotalElementCount(withRightSplit rightHandle: _Node.UnsafeHandle) {
    let originalTotalElements = self.numTotalElements
    var totalChildElements = 0
    
    if !self.isLeaf {
      // Calculate total amount of child elements
      // TODO: potentially evaluate min(left.children, right.children),
      // but the cost of the branch will likely exceed the cost of 1 copmarison
      for i in 0..<self.numChildren {
        totalChildElements += self[childAt: i].storage.header.totalElements
      }
    }
    
    assert(totalChildElements >= 0, "Cannot have negative number of child elements.")
    
    self.numTotalElements = self.numElements + totalChildElements
    rightHandle.numTotalElements = originalTotalElements - self.numTotalElements
    
    checkInvariants()
  }
}

// MARK: Node Mutations
extension _Node.UnsafeHandle {
  /// Inserts a value into this node without considering the children. Be careful when using
  /// this as you can violate the BTree invariants if not careful.
  @inlinable
  internal func immediatelyInsert(
    element: _Node.Element,
    withRightChild rightChild: _Node?,
    at insertionIndex: Int
  ) -> _Node.Splinter? {
    assertMutable()
    assert(self.isLeaf == (rightChild == nil), "A child can only be inserted iff the node is a leaf.")
    
    // If we have a full B-Tree, we'll need to splinter
    if self.numElements == self.capacity {
      // Right median == left median for BTrees with odd capacity
      let rightMedian = self.numElements / 2
      let leftMedian = (self.numElements - 1) / 2
      
      var splinterElement: _Node.Element
      var rightNode = _Node(withCapacity: self.capacity, isLeaf: self.isLeaf)
      
      if insertionIndex == rightMedian {
        splinterElement = element
        
        let numLeftElements = rightMedian
        let numRightElements = self.numElements - rightMedian
        
        rightNode.update { handle in
          self.moveElements(toHandle: handle, fromIndex: rightMedian, toIndex: 0, count: numRightElements)
          
          // TODO: also possible to do !self.isLeaf and force unwrap right child to
          // help the compiler avoid this branch.
          if !self.isLeaf {
            handle.children.unsafelyUnwrapped.initialize(to: rightChild.unsafelyUnwrapped)
            self.moveChildren(toHandle: handle, fromIndex: rightMedian + 1, toIndex: 1, count: numRightElements)
          }
          
          self.numElements = numLeftElements
          handle.numElements = numRightElements
          
          self.recomputeTotalElementCount(withRightSplit: handle)
        }
      } else if insertionIndex > rightMedian {
        // This branch is almost certainly correct
        splinterElement = self.moveElement(at: rightMedian)
        
        rightNode.update { handle in
          let insertionIndexInRightNode = insertionIndex - (rightMedian + 1)
          
          self.moveElements(
            toHandle: handle,
            fromIndex: rightMedian + 1,
            toIndex: 0,
            count: insertionIndexInRightNode
          )
          
          self.moveElements(
            toHandle: handle,
            fromIndex: insertionIndex,
            toIndex: insertionIndexInRightNode + 1,
            count: self.numElements - insertionIndex
          )
          
          if !self.isLeaf {
            self.moveChildren(
              toHandle: handle,
              fromIndex: rightMedian + 1,
              toIndex: 0,
              count: insertionIndex - rightMedian
            )
            
            self.moveChildren(
              toHandle: handle,
              fromIndex: insertionIndex + 1,
              toIndex: insertionIndexInRightNode + 2,
              count: self.numElements - insertionIndex
            )
          }
          
          handle.setElement(element, withRightChild: rightChild, at: insertionIndexInRightNode)
          
          handle.numElements = self.numElements - rightMedian
          self.numElements = rightMedian
          
          self.recomputeTotalElementCount(withRightSplit: handle)
        }
      } else {
        // insertionIndex < rightMedian
        splinterElement = self.moveElement(at: leftMedian)
        
        rightNode.update { handle in
          self.moveElements(
            toHandle: handle,
            fromIndex: leftMedian + 1,
            toIndex: 0,
            count: self.numElements - leftMedian - 1
          )
          
          self.moveElements(
            toHandle: self,
            fromIndex: insertionIndex,
            toIndex: insertionIndex + 1,
            count: leftMedian - insertionIndex
          )
          
          if !self.isLeaf {
            self.moveChildren(
              toHandle: handle,
              fromIndex: leftMedian + 1,
              toIndex: 0,
              count: self.numElements - leftMedian
            )
            
            self.moveChildren(
              toHandle: self,
              fromIndex: insertionIndex + 1,
              toIndex: insertionIndex + 2,
              count: leftMedian - insertionIndex
            )
          }
          
          self.setElement(element, withRightChild: rightChild, at: insertionIndex)
          
          handle.numElements = self.numElements - leftMedian - 1
          self.numElements = leftMedian + 1
          
          self.recomputeTotalElementCount(withRightSplit: handle)
        }
      }
      
      return _Node.Splinter(
        median: splinterElement,
        rightChild: rightNode
      )
    } else {
      // Shift over elements near the insertion index.
      let numElemsToShift = self.numElements - insertionIndex
      self.moveElements(
        toHandle: self,
        fromIndex: insertionIndex,
        toIndex: insertionIndex + 1,
        count: numElemsToShift
      )
      
      if !self.isLeaf {
        let numChildrenToShift = self.numChildren - insertionIndex - 1
        self.moveChildren(
          toHandle: self,
          fromIndex: insertionIndex + 1,
          toIndex: insertionIndex + 2,
          count: numChildrenToShift
        )
      }
      
      self.setElement(element, withRightChild: rightChild, at: insertionIndex)
      self.numElements += 1
      self.numTotalElements += 1
      
      return nil
    }
  }
  
  /// Inserts a splinter, attaching the children appropriately
  /// - Parameters:
  ///   - splinter: The splinter object from a child
  ///   - insertionIndex: The index of the child which produced the splinter
  /// - Returns: Another splinter which may need to be propogated upward
  @inlinable
  @inline(__always)
  internal func immediatelyInsert(splinter: _Node.Splinter, at insertionIndex: Int) -> _Node.Splinter? {
    return self.immediatelyInsert(element: splinter.median, withRightChild: splinter.rightChild, at: insertionIndex)
  }
}

// MARK: CustomStringConvertible
extension _Node.UnsafeHandle: CustomStringConvertible {
  /// A textual representation of this instance, suitable for debugging.
  public var description: String {
    var result = "Node<\(Key.self), \(Value.self)>(["
    var first = true
    for index in 0..<self.numElements {
      if first {
        first = false
      } else {
        result += ", "
      }
      result += "("
      debugPrint(self[keyAt: index], terminator: ", ", to: &result)
      debugPrint(self[valueAt: index], terminator: ")", to: &result)
    }
    result += "], "
    if let children = self.children {
      debugPrint(Array(UnsafeBufferPointer(start: children, count: self.numChildren)), terminator: ")", to: &result)
    } else {
      result += "[])"
    }
    return result
  }
}

// MARK: CustomDebugStringConvertible
extension _Node.UnsafeHandle: CustomDebugStringConvertible {
  #if DEBUG
  private enum PrintPosition { case start, end, middle }
  private func indentDescription(_ node: _Node<Key, Value>.UnsafeHandle, position: PrintPosition) -> String {
    let label = "(\(node.numTotalElements))"
    
    let spaces = String(repeating: " ", count: label.count)
    
    let lines = describeNode(node).split(separator: "\n")
    return lines.enumerated().map({ index, line in
      var lineToInsert = line
      let middle = (lines.count - 1) / 2
      if index < middle {
        if position == .start {
          return "   " + spaces + lineToInsert
        } else {
          return "┃  " + spaces + lineToInsert
        }
      } else if index > middle {
        if position == .end {
          return "   " + spaces + lineToInsert
        } else {
          return "┃  " + spaces + lineToInsert
        }
      } else {
        switch line[line.startIndex] {
        case "╺": lineToInsert.replaceSubrange(...line.startIndex, with: "━")
        case "┗": lineToInsert.replaceSubrange(...line.startIndex, with: "┻")
        case "┏": lineToInsert.replaceSubrange(...line.startIndex, with: "┳")
        case "┣": lineToInsert.replaceSubrange(...line.startIndex, with: "╋")
        default: break
        }
        
        switch position {
        case .start: return "┏━\(label)━" + lineToInsert
        case .middle: return "┣━\(label)━" + lineToInsert
        case .end: return "┗━\(label)━" + lineToInsert
        }
      }
    }).joined(separator: "\n")
  }
  
  /// A textual representation of this instance, suitable for debugging.
  private func describeNode(_ node: _Node<Key, Value>.UnsafeHandle) -> String {
    var result = ""
    for index in 0..<node.numElements {
      if !node.isLeaf {
        let child = node[childAt: index]
        let childDescription = child.read {
          indentDescription($0, position: index == 0 ? .start : .middle)
        }
        result += childDescription + "\n"
      }
      
      if node.isLeaf {
        if node.numElements == 1 {
          result += "╺━ "
        } else if index == node.numElements - 1 {
          result += "┗━ "
        } else if index == 0 {
          result += "┏━ "
        } else {
          result += "┣━ "
        }
      } else {
        result += "┣━ "
      }
      
      debugPrint(node[keyAt: index], terminator: ": ", to: &result)
      debugPrint(node[valueAt: index], terminator: "", to: &result)
      
      if !node.isLeaf && index == node.numElements - 1 {
        let childDescription = node[childAt: index + 1].read {
          indentDescription($0, position: .end)
        }
        result += "\n" + childDescription
      }
      
      result += "\n"
    }
    return result
  }
  
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return indentDescription(self, position: .end)
  }
  #else
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return self.description
  }
  #endif // DEBUG
}
