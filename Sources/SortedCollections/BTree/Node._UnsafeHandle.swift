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

extension Node {
  @usableFromInline
  internal struct _UnsafeHandle {
    @usableFromInline
    internal let keyHeader: UnsafeMutablePointer<_BufferHeader>
    
    @usableFromInline
    internal let valueHeader: UnsafeMutablePointer<_BufferHeader>
    
    @usableFromInline
    internal let childrenHeader: UnsafeMutablePointer<_BufferHeader>
    
    @usableFromInline
    internal let keys: UnsafeMutablePointer<Key>
    
    @usableFromInline
    internal let values: UnsafeMutablePointer<Value>
    
    @usableFromInline
    internal let children: UnsafeMutablePointer<Node<Key, Value>>
    
    @usableFromInline
    internal let capacity: Int
    
    @inlinable
    @inline(__always)
    internal init(
      keyHeader: UnsafeMutablePointer<_BufferHeader>,
      valueHeader: UnsafeMutablePointer<_BufferHeader>,
      childrenHeader: UnsafeMutablePointer<_BufferHeader>,
      keys: UnsafeMutablePointer<Key>,
      values: UnsafeMutablePointer<Value>,
      children: UnsafeMutablePointer<Node<Key, Value>>,
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
    
    /// Creates a mutable version of this handle
    @inlinable
    @inline(__always)
    internal init(mutableCopyOf handle: _UnsafeHandle) {
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
      nonmutating set { keyHeader.pointee.count = newValue }
    }
    
    @inlinable
    @inline(__always)
    internal var numValues: Int {
      get { valueHeader.pointee.count }
      nonmutating set { valueHeader.pointee.count = newValue }
    }
    
    @inlinable
    @inline(__always)
    internal var numChildren: Int {
      get { childrenHeader.pointee.count }
      nonmutating set { childrenHeader.pointee.count = newValue }
    }
  }
}

// MARK: Subscript
extension Node._UnsafeHandle {
  @inlinable
  @inline(__always)
  internal subscript(elementAt index: Int) -> Node.Element {
    get {
      assert(index < self.numKeys, "Node element subscript out of bounds.")
      return (key: self.keys[index], value: self.values[index])
    }
    
    nonmutating set(newElement) {
      assert(index <= self.numKeys, "Node element subscript out of bounds.")
      assert(index < self.capacity)
      
      // The subscript for UnsafeMutablePointer will deinitialize the
      // old value, so we'll take steps to not uninitialize the memory
      // if we're not overwriting an existing spot in the
      if index == self.numKeys {
        self.keys.advanced(by: index).initialize(to: newElement.key)
        self.values.advanced(by: index).initialize(to: newElement.value)
        
        self.numKeys += 1
        self.numValues += 1
      } else {
        // TODO: ensure that the subscript does deintialize the old
        // element
        self.keys[index] = newElement.key
        self.values[index] = newElement.value
      }
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
  internal subscript(childAt index: Int) -> Node {
    get {
      assert(index < self.numChildren, "Node child subscript out of bounds")
      return self.children[index]
    }
    
    nonmutating set(newChild) {
      assert(index <= self.numChildren, "Node element subscript out of bounds.")
      assert(index < self.capacity)
      
      // The subscript for UnsafeMutablePointer will deinitialize the
      // old value, so we'll take steps to not uninitialize the memory
      // if we're not overwriting an existing spot in the
      if index == self.numChildren {
        self.children.advanced(by: index).initialize(to: newChild)
      } else {
        self.children[index] = newChild
      }
    }
  }
}

// MARK: Binary Search
extension Node._UnsafeHandle {
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

// MARK: Node Mutations
extension Node._UnsafeHandle {
  /// Inserts a value into this node without considering the children. Be careful when using
  /// this as you can violate the BTree invariants if not careful.
  @usableFromInline
  internal func _immediatelyInsertValue(_ value: Value, forKey key: Key, at insertionIndex: Int) -> Node._Splinter? {
    var splinter: Node._Splinter? = nil
    
    // If we have a full B-Tree, we'll need to splinter
    if numKeys == capacity {
      // v------- median - 1
      // 0 1 2 3
      //   ^-- median
      //     ^-- median + 1
      let medianIndex = self.numKeys / 2
      
      let leftNode = self
      
      // TODO: optimize this to directly initialize
      let rightNode = Node(withCapacity: capacity)
      rightNode.update { handle in
        let rightNodeElements = medianIndex + 1
        handle.keys.moveInitialize(
          from: self.keys.advanced(by: medianIndex + 1),
          count: numKeys - (medianIndex + 1)
        )
        
        handle.values.moveInitialize(
          from: self.keys.advanced(by: medianIndex + 1),
          count: numKeys - (medianIndex + 1)
        )
      }
      
      
    } else {
      // TODO: will this trigger a swift_retain/swift_release for each element??
      self.keys
        .advanced(by: insertionIndex + 1)
        .moveAssign(
          from: self.keys.advanced(by: insertionIndex),
          count: numKeys - insertionIndex)
      
      self.values
        .advanced(by: insertionIndex + 1)
        .moveAssign(
          from: self.values.advanced(by: insertionIndex),
          count: numValues - insertionIndex)
      
      self[elementAt: insertionIndex] = (key: key, value: value)
    }
    
    self.numKeys += 1
    self.numValues += 1
    
    return splinter
  }
  
  /// Inserts a value into this node or the appropriate child.
  /// - Parameters:
  ///   - value: The respect value to insert.
  ///   - key: A key to insert. If this key exists it'll be inserted at last valid position.
  /// - Returns: A splinter which can be used to construct the new upper and right children.
  @inlinable
  internal func insertValue(_ value: Value, forKey key: Key) -> Node._Splinter? {
    let insertionIndex = self.lastIndex(of: key)
    
    // TODO: figure out how to handle duplicates properly
    
    // Check the children if it exists. Otherwise we'll assume we're at a "leaf".
    // This assumes we have a well-formed BTree
    if insertionIndex < numChildren {
      // TODO: consider the cost of recursion. Shouldn't be significant as BTrees should maintain very
      // low height.
      let childInsertion = self[childAt: insertionIndex].update({ $0.insertValue(value, forKey: key) })
      
      // If the child splintered, we'll need to readjust the node to handle that.
      if let childSplinter = childInsertion {
        // The median
        // TOD: implement
        
      }
      
      return nil
    } else {
      return self._immediatelyInsertValue(value, forKey: key, at: insertionIndex)
    }
  }
  
}
