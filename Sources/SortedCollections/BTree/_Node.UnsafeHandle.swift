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
    /// - Warning: Do not access on a leaf, else will panic.
    @inlinable
    @inline(__always)
    internal var numChildren: Int {
      // TODO: should this be a method given that it may panic?
      assert(!self.isLeaf, "Cannot access the child count on a leaf.")
      return self.numElements + 1
    }
    
    // TODO: not sure what the branch predictor would do for this, given
    // this is perfectly impredictable without context.
    @inlinable
    @inline(__always)
    internal var isLeaf: Bool { children == nil }
  }
}

// MARK: Subscript
extension _Node.UnsafeHandle {
  @inlinable
  @inline(__always)
  internal subscript(elementAt slot: Int) -> _Node.Element {
    get {
      assert(slot < self.numElements, "Node element subscript out of bounds.")
      return (key: self.keys[slot], value: self.values[slot])
    }
  }
  
  @inlinable
  @inline(__always)
  internal subscript(keyAt slot: Int) -> Key {
    _read {
      assert(slot < self.numElements, "Node key subscript out of bounds.")
      yield self.keys[slot]
    }
  }
  
  @inlinable
  @inline(__always)
  internal subscript(valueAt slot: Int) -> Value {
    _read {
      assert(slot < self.numElements, "Node values subscript out of bounds.")
      yield self.values[slot]
    }
  }
  
  // TODO: consider implementing `_modify` for these subscripts
  @inlinable
  @inline(__always)
  internal subscript(childAt slot: Int) -> _Node {
    _read {
      assert(!isLeaf, "Cannot access children of leaf node.")
      assert(slot < self.numChildren, "Node child subscript out of bounds")
      yield self.children.unsafelyUnwrapped[slot]
    }
    
    nonmutating _modify {
      assert(!isLeaf, "Cannot modify children of leaf node.")
      var child = self.children.unsafelyUnwrapped.advanced(by: slot).move()
      defer { self.children.unsafelyUnwrapped.advanced(by: slot).initialize(to: child) }
      yield &child
    }
  }
}

// MARK: Binary Search
extension _Node.UnsafeHandle {
  /// Performs O(log n) search for a key, returning the first instance when duplicates exist. This
  /// returns the first possible insertion point for `key`.
  /// - Parameter key: The key to search for within the node.
  /// - Returns: Either the slot if the first instance of the key, otherwise
  ///     the valid insertion point for the key.
  @inlinable
  internal func firstSlot(for key: Key) -> Int {
    var start: Int = 0
    var end: Int = self.numElements
    
    while end > start {
      let mid = (end &- start) / 2 &+ start
      
      // TODO: make this info a conditional_mov
      if key <= self.keys[mid] {
        end = mid
      } else {
        start = mid &+ 1
      }
    }
    
    return end
  }
  
  /// Performs O(log n) search for a key, returning the last instance when duplicates exist. This
  /// returns the last possible valid insertion point for `key`.
  /// - Parameter key: The key to search for within the node.
  /// - Returns: Either the slot after the last instance of the key, otherwise
  ///     the valid insertion point for the key.
  @inlinable
  internal func lastSlot(for key: Key) -> Int {
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
  
  /// Searches the node and its children for a given value
  @inlinable
  internal func findValue(for key: Key) -> Value? {
    let slot = self.firstSlot(for: key)
    
    if slot < self.numElements && self[keyAt: slot] == key {
      return self[valueAt: slot]
    } else {
      if self.isLeaf {
        return nil
      } else {
        return self[childAt: slot].read { $0.findValue(for: key) }
      }
    }
  }
}

// MARK: Element-wise Buffer Operations
extension _Node.UnsafeHandle {
  /// Moves elements from the current handle to a new handle
  /// - Parameters:
  ///   - newHandle: The destination handle to write to which could be the same
  ///       as the source to move within a handle.
  ///   - sourceSlot: The offset of the source handle to move from.
  ///   - destinationSlot: The offset of the destintion handle to write to.
  ///   - count: The amount of values to move
  /// - Warning: This does not adjust the buffer counts.
  @inlinable
  @inline(__always)
  internal func moveElements(
    toHandle newHandle: _Node.UnsafeHandle,
    fromSlot sourceSlot: Int,
    toSlot destinationSlot: Int,
    count: Int
  ) {
    assert(sourceSlot >= 0, "Move source slot must be positive.")
    assert(destinationSlot >= 0, "Move destination slot must be positive.")
    assert(count >= 0, "Amount of elements to move be positive.")
    assert(sourceSlot + count <= self.capacity, "Cannot move elements beyond source buffer capacity.")
    assert(destinationSlot + count <= newHandle.capacity, "Cannot move elements beyond destination buffer capacity.")
    
    self.assertMutable()
    newHandle.assertMutable()
    
    newHandle.keys.advanced(by: destinationSlot)
      .moveInitialize(from: self.keys.advanced(by: sourceSlot), count: count)
    
    newHandle.values.advanced(by: destinationSlot)
      .moveInitialize(from: self.values.advanced(by: sourceSlot), count: count)
  }
  
  /// Moves children from the current handle to a new handle
  /// - Parameters:
  ///   - newHandle: The destination handle to write to which could be the same
  ///       as the source to move within a handle.
  ///   - sourceSlot: The offset of the source handle to move from.
  ///   - destinationSlot: The offset of the destintion handle to write to.
  ///   - count: The amount of values to move
  /// - Warning: This does not adjust the buffer counts.
  /// - Warning: This will trap if either the source and destination handles are leaves.
  @inlinable
  @inline(__always)
  internal func moveChildren(
    toHandle newHandle: _Node.UnsafeHandle,
    fromSlot sourceSlot: Int,
    toSlot destinationSlot: Int,
    count: Int
  ) {
    assert(sourceSlot >= 0, "Move source slot must be positive.")
    assert(destinationSlot >= 0, "Move destination slot must be positive.")
    assert(count >= 0, "Amount of children to move be positive.")
    assert(sourceSlot + count <= self.capacity + 1, "Cannot move children beyond source buffer capacity.")
    assert(destinationSlot + count <= newHandle.capacity + 1, "Cannot move children beyond destination buffer capacity.")
    assert(!newHandle.isLeaf, "Cannot move children to a leaf node")
    assert(!self.isLeaf, "Cannot move chidlren from a leaf node")
    
    self.assertMutable()
    newHandle.assertMutable()
    
    newHandle.children.unsafelyUnwrapped.advanced(by: destinationSlot)
      .moveInitialize(from: self.children.unsafelyUnwrapped.advanced(by: sourceSlot), count: count)
  }
  
  /// Inserts a new element somewhere into the handle.
  /// - Parameters:
  ///   - element: The element to insert which the node will take ownership of.
  ///   - slot: An uninitialized slot in the buffer to insert the element into.
  /// - Warning: This does not adjust the buffer counts.
  @inlinable
  @inline(__always)
  internal func setElement(_ element: _Node.Element, withRightChild rightChild: _Node?, at slot: Int) {
    assertMutable()
    assert(slot < self.capacity, "Cannot insert beyond node capacity.")
    assert(self.isLeaf == (rightChild == nil), "A child can only be inserted iff the node is a leaf.")
    
    self.keys.advanced(by: slot).initialize(to: element.key)
    self.values.advanced(by: slot).initialize(to: element.value)
    
    if let rightChild = rightChild {
      self.children.unsafelyUnwrapped.advanced(by: slot + 1).initialize(to: rightChild)
    }
  }
  
  /// Moves an element out of the handle and returns it.
  ///
  /// This may leave a hold within the node's buffer so it is critical to ensure that
  /// it is filled, either by inserting a new element or some other operation.
  ///
  /// - Parameter slot: The in-bounds slot of an element to move out
  /// - Returns: A tuple of the key and value.
  /// - Warning: This does not adjust buffer counts
  @inlinable
  @inline(__always)
  internal func moveElement(at slot: Int) -> _Node.Element {
    assertMutable()
    assert(slot < self.numElements, "Attempted to move out-of-bounds element.")
    
    return (
      key: self.keys.advanced(by: slot).move(),
      value: self.values.advanced(by: slot).move()
    )
  }
  
  /// Recomputes the total amount of elements in two nodes.
  ///
  /// Use this to recompute the tracked total element counts for the current node when it
  /// splits. This performs a shallow recalculation, assuming that its children's counts are
  /// already accurate.
  ///
  /// - Parameter rightHandle: A handle to the right-half of the split.
  @inlinable
  @inline(__always)
  internal func recomputeTotalElementCount(withRightSplit rightHandle: _Node.UnsafeHandle) {
    assertMutable()
    
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
  
  /// Removes a key-value pair from a given slot within the node. This is assumed to
  /// run on a leaf.
  /// 
  /// - Parameter slot: The slot to remove which must be in-bounds.
  /// - Returns: The element that was removed..
  /// - Warning: This does not perform any balancing or rotation.
  @inlinable
  @inline(__always)
  internal func removeElement(at slot: Int) -> _Node.Element {
    assertMutable()
    assert(self.isLeaf, "Attempt to call removeElement(at:) on a leaf.")
    assert(slot < self.numElements, "Attempt to remove out-of-bounds element.")
    
    let element = self.moveElement(at: slot)
    
    // Shift everything else over to the left
    self.moveElements(
      toHandle: self,
      fromSlot: slot + 1,
      toSlot: slot,
      count: self.numElements - slot - 1
    )
    
    self.numElements -= 1
    self.numTotalElements -= 1
    
    return element
  }
}

// MARK: Tree-Wise Operations
extension _Node.UnsafeHandle {
  @usableFromInline
  internal typealias ElementReference = (handle: _Node.UnsafeHandle, slot: Int)
  
  // TODO: see if these closures optimize well
  /// Obtains a handle to the node's immediate predecessor.  If a predecessor
  /// does not exist, the closure recieves a `nil` parameter.
//  @inlinable
//  @inline(__always)
//  internal func withPredecessor<R>(
//    of slot: Int,
//    _ body: (ElementReference?) -> R
//  ) -> R {
//    assert(slot < self.numElements, "Cannot get predecessor for out-of-bounds slot.")
//
//    var currentNode = self
//
//    return body(nil)
//  }
}
