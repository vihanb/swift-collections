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
    internal let keyHeader: UnsafeMutablePointer<BufferHeader>
    
    @usableFromInline
    internal let valueHeader: UnsafeMutablePointer<BufferHeader>
    
    @usableFromInline
    internal let childrenHeader: UnsafeMutablePointer<BufferHeader>?
    
    @usableFromInline
    internal let keys: UnsafeMutablePointer<Key>
    
    @usableFromInline
    internal let values: UnsafeMutablePointer<Value>
    
    @usableFromInline
    internal let children: UnsafeMutablePointer<_Node<Key, Value>>?
    
    @usableFromInline
    internal let capacity: Int
    
    @inlinable
    @inline(__always)
    internal init(
      keyHeader: UnsafeMutablePointer<BufferHeader>,
      valueHeader: UnsafeMutablePointer<BufferHeader>,
      childrenHeader: UnsafeMutablePointer<BufferHeader>?,
      keys: UnsafeMutablePointer<Key>,
      values: UnsafeMutablePointer<Value>,
      children: UnsafeMutablePointer<_Node<Key, Value>>?,
      capacity: Int,
      isMutable: Bool
    ) {
      self.keyHeader = keyHeader
      self.valueHeader = valueHeader
      self.childrenHeader = childrenHeader
      self.keys = keys
      self.values = values
      self.children = children
      self.capacity = capacity
      
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
      assert(isLeaf || numChildren == numKeys + 1, "Node must have either zero children or a child on the side of each key.")
      assert(numKeys == numKeys, "Node must have equal count of keys and values ")
      
      if numKeys > 1 {
        for i in 0..<(numKeys - 1) {
          precondition(self[keyAt: i] <= self[keyAt: i + 1], "Node is out-of-order.")
        }
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
        keyHeader: handle.keyHeader,
        valueHeader: handle.valueHeader,
        childrenHeader: handle.childrenHeader,
        keys: handle.keys,
        values: handle.values,
        children: handle.children,
        capacity: handle.capacity,
        isMutable: true
      )
    }
    
    // MARK: Convenience properties
    @inlinable
    @inline(__always)
    internal var numKeys: Int {
      get { keyHeader.pointee.count }
      nonmutating set { assertMutable(); keyHeader.pointee.count = newValue }
    }
    
    @inlinable
    @inline(__always)
    internal var numValues: Int {
      get { valueHeader.pointee.count }
      nonmutating set { assertMutable(); valueHeader.pointee.count = newValue }
    }
    
    @inlinable
    @inline(__always)
    internal var numChildren: Int {
      get { childrenHeader?.pointee.count ?? 0 }
      nonmutating set {
        assertMutable()
        #if DEBUG
        if isLeaf && newValue != 0 {
          assertionFailure("Cannot set non-zero number of children on a leaf")
        }
        #endif
        childrenHeader!.pointee.count = newValue
      }
    }
    
    @inlinable
    @inline(__always)
    internal var isLeaf: Bool { childrenHeader == nil }
  }
}

// MARK: Subscript
extension _Node.UnsafeHandle {
  @inlinable
  @inline(__always)
  internal subscript(elementAt index: Int) -> _Node.Element {
    get {
      assert(index < self.numKeys, "Node element subscript out of bounds.")
      return (key: self.keys[index], value: self.values[index])
    }
    
    nonmutating set(newElement) {
      assertMutable()
      assert(index < self.numKeys, "Node element subscript out of bounds.")
      
      // TODO: ensure that the subscript does deintialize the old
      // element
      self.keys[index] = newElement.key
      self.values[index] = newElement.value
    }
  }
  
  @inlinable
  @inline(__always)
  internal subscript(keyAt index: Int) -> Key {
    assert(index < self.numKeys, "Node key subscript out of bounds.")
    return self.keys[index]
  }
  
  @inlinable
  @inline(__always)
  internal subscript(valueAt index: Int) -> Value {
    assert(index < self.numValues, "Node values subscript out of bounds.")
    return self.values[index]
  }
  
  // TODO: consider implementing `_modify` for these subscripts
  @inlinable
  @inline(__always)
  internal subscript(childAt index: Int) -> _Node {
    get {
      assert(index < self.numChildren, "Node child subscript out of bounds")
      assert(!isLeaf, "Cannot access children of leaf node.")
      return self.children![index]
    }
    
    nonmutating set(newChild) {
      assertMutable()
      assert(index < self.numChildren, "Node element subscript out of bounds.")
      assert(!isLeaf, "Cannot access children of leaf node.")
      self.children![index] = newChild
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
    var end: Int = self.numKeys
    
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
    var end: Int = self.numKeys
    
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
  /// Moves elements from the current handle to the beginning of a new handle. This will deinitialize
  /// the elements from the current handle. The destination must be uninitialized
  /// - Parameters:
  ///   - newHandle: The destination handle to write to.
  ///   - sourceIndex: The offset of the source handle to move from.
  ///   - destinationIndex: The offset of the destintion handle to write to. Assumes
  ///       that all previous values have beeh initialized.
  @inlinable
  @inline(__always)
  internal func moveElements(
    toHandle newHandle: _Node.UnsafeHandle,
    fromIndex sourceIndex: Int,
    toIndex destinationIndex: Int = 0
  ) {
    assert(sourceIndex >= 0, "Move source index must be positive.")
    assert(destinationIndex >= 0, "Move destination index must be positive.")
     
    self.assertMutable()
    newHandle.assertMutable()
    
    let count = self.numKeys - sourceIndex
    if count <= 0 { return }
    
    // Ensure the newHandle has enough space
    assert(destinationIndex + count <= newHandle.capacity, "Oversized move operation causing overflow.")
    
    // TODO: handle children
    newHandle.keys.advanced(by: destinationIndex).moveInitialize(from: self.keys.advanced(by: sourceIndex), count: count)
    newHandle.values.advanced(by: destinationIndex).moveInitialize(from: self.values.advanced(by: sourceIndex), count: count)
    
    self.setElementCount(sourceIndex)
    newHandle.setElementCount(destinationIndex + count)
  }
  
  /// Moves elements from the current handle to the beginning of a new handle, while inserting an
  /// element somewhere in the middle. This adjusts element counts.
  /// - Parameters:
  ///   - element: The element to insert and take ownership for
  ///   - insertionIndex: The index relative to the *source* to insert into.
  ///   - sourceHandle: The source handle to move from.
  ///   - sourceIndex: The source values to move from, deinitializing from this
  ///       index until the end,
  ///   - destinationIndex: The destination index to start initializing from.
  @inlinable
  @inline(__always)
  internal func moveWithNewElement(
    _ element: _Node.Element,
    at insertionIndex: Int,
    fromHandle sourceHandle: _Node.UnsafeHandle,
    fromIndex sourceIndex: Int,
    toIndex destinationIndex: Int = 0
  ) {
    // TOOD: revisit this ugly function
    assertMutable()
    sourceHandle.assertMutable()
    
    let movedElements = sourceHandle.numKeys - sourceIndex
    let destinationInsertionIndex = destinationIndex + (insertionIndex - sourceIndex)
    sourceHandle.moveElements(toHandle: self, fromIndex: insertionIndex, toIndex: destinationInsertionIndex + 1)
    sourceHandle.moveElements(toHandle: self, fromIndex: sourceIndex, toIndex: destinationIndex)
    self.insertElement(element, at: destinationInsertionIndex)
    self.setElementCount(destinationIndex + movedElements + 1)
  }
  
  /// Inserts a new element somewhere into the handle.
  /// - Parameters:
  ///   - element: The element to insert which the node will take ownership of.
  ///   - index: An uninitialized index in the buffer to insert the element into.
  /// - Warning: This does not adjust the buffer counts.
  @inlinable
  @inline(__always)
  internal func insertElement(_ element: _Node.Element, at index: Int) {
    assertMutable()
    assert(index < self.capacity, "Cannot insert beyond node capacity.")
    
    self.keys.advanced(by: index).initialize(to: element.key)
    self.values.advanced(by: index).initialize(to: element.value)
  }
  
  /// Moves an element out of the handle
  /// - Parameter index: The in-bounds index of an element to move out
  /// - Returns: A tuple of the key and value.
  /// - Warning: This does not adjust buffer counts
  @inlinable
  @inline(__always)
  internal func moveElement(at index: Int) -> _Node.Element {
    assertMutable()
    assert(index < self.numKeys, "Attempted to move out-of-bounds element.")
    
    return (
      key: self.keys.advanced(by: index).move(),
      value: self.values.advanced(by: index).move()
    )
  }
  
  /// Sets the number of elements in this node
  @inlinable
  @inline(__always)
  internal func setElementCount(_ numElements: Int) {
    assertMutable()
    assert(numElements <= self.capacity, "Cannot set more elements than capacity.")
    
    self.numKeys = numElements
    self.numValues = numElements
  }
}

// MARK: Node Mutations
extension _Node.UnsafeHandle {
  /// Inserts a value into this node without considering the children. Be careful when using
  /// this as you can violate the BTree invariants if not careful.
  @usableFromInline
  internal func _immediatelyInsertElement(_ element: _Node.Element, at insertionIndex: Int) -> _Node.Splinter? {
    assertMutable()
    
    // If we have a full B-Tree, we'll need to splinter
    if self.numKeys == self.capacity {
      // Right median == left median for BTrees with odd capacity
      let rightMedian = self.numKeys / 2
      let leftMedian = (self.numKeys - 1) / 2
      
      var splinterElement: _Node.Element
      var rightNode = _Node(isLeaf: self.isLeaf, withCapacity: self.capacity)
      
      if insertionIndex == rightMedian {
        splinterElement = element
        
        rightNode.update { handle in
          self.moveElements(toHandle: handle, fromIndex: rightMedian)
        }
      } else if insertionIndex > rightMedian {
        rightNode.update { handle in
          handle.moveWithNewElement(
            element,
            at: insertionIndex,
            fromHandle: self,
            fromIndex: rightMedian + 1,
            toIndex: 0
          )
        }
        
        splinterElement = self.moveElement(at: rightMedian)
        self.setElementCount(rightMedian)
      } else {
        // insertionIndex < rightMedian
        
        rightNode.update { handle in
          self.moveElements(toHandle: handle, fromIndex: leftMedian + 1, toIndex: 0)
        }
        
        splinterElement = self.moveElement(at: leftMedian)
        self.setElementCount(leftMedian)
      }
      
      return _Node.Splinter(
        median: splinterElement,
        rightChild: rightNode
      )
    } else {
      // Shift over elements near the insertion index.
      self.moveWithNewElement(
        element,
        at: insertionIndex,
        fromHandle: self,
        fromIndex: insertionIndex,
        toIndex: insertionIndex
      )
      
      return nil
    }
  }
  
  /// Inserts a splinter, attaching the children appropriately
  /// - Parameters:
  ///   - splinter: The splinter object from a child
  ///   - insertionIndex: The index of the child which produced the splinter
  /// - Returns: Another splinter which may need to be propogated upward
  @inlinable
  internal func _insertSplinter(_ splinter: _Node.Splinter, at insertionIndex: Int) -> _Node.Splinter? {
    assertMutable()
    
    let newSplinter = self._immediatelyInsertElement(splinter.median, at: insertionIndex)
    if var newSplinter = newSplinter {
      newSplinter.rightChild.update { handle in
        handle[childAt: 0] = splinter.rightChild
      }
      return newSplinter
    } else {
      self[childAt: insertionIndex + 1] = splinter.rightChild
      return nil
    }
  }
  
  /// Inserts a value into this node or the appropriate child.
  /// - Parameters:
  ///   - value: The respect value to insert.
  ///   - key: A key to insert. If this key exists it'll be inserted at last valid position.
  /// - Returns: A splinter which can be used to construct the new upper and right children.
  @inlinable
  internal func insertElement(_ element: _Node.Element) -> _Node.Splinter? {
    assertMutable()
    checkInvariants()
    
    let insertionIndex = self.lastIndex(of: element.key)
    
    // We need to try to insert as deep as possible as first, and have the splinter
    // bubble up.
    if self.isLeaf {
      return self._immediatelyInsertElement(element, at: insertionIndex)
    } else {
      let splinter = self[childAt: insertionIndex].update({ $0.insertElement(element) })
      
      if let splinter = splinter {
        return self._insertSplinter(splinter, at: insertionIndex)
      }
      
      return nil
    }
  }
  
}
