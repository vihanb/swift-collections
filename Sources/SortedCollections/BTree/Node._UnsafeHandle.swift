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
    internal let keyHeader: UnsafePointer<_BufferHeader>
    
    @usableFromInline
    internal let valueHeader: UnsafePointer<_BufferHeader>
    
    @usableFromInline
    internal let childrenHeader: UnsafePointer<_BufferHeader>
    
    @usableFromInline
    internal let keys: UnsafePointer<Key>
    
    @usableFromInline
    internal let values: UnsafePointer<Value>
    
    @usableFromInline
    internal let children: UnsafePointer<Node<Key, Value>>
    
    // MARK: Convenience properties
    @inlinable
    @inline(__always)
    internal var numElements: Int { keyHeader.pointee.count }
    
    @inlinable
    @inline(__always)
    internal var numChildren: Int { childrenHeader.pointee.count }
    
    @inlinable
    @inline(__always)
    internal init(
      keyHeader: UnsafePointer<_BufferHeader>,
      valueHeader: UnsafePointer<_BufferHeader>,
      childrenHeader: UnsafePointer<_BufferHeader>,
      keys: UnsafePointer<Key>,
      values: UnsafePointer<Value>,
      children: UnsafePointer<Node<Key, Value>>
    ) {
      self.keyHeader = keyHeader
      self.valueHeader = valueHeader
      self.childrenHeader = childrenHeader
      self.keys = keys
      self.values = values
      self.children = children
    }
  }
}

// MARK: Subscript
extension Node._UnsafeHandle {
  @inlinable
  @inline(__always)
  internal subscript(elementAt index: Int) -> Node.Element {
    assert(index < self.numElements, "Node element subscript out of bounds.")
    let key = self.keys.advanced(by: index).pointee
    let value = self.values.advanced(by: index).pointee
    return (key: key, value: value)
  }
  
  @inlinable
  @inline(__always)
  internal subscript(childAt index: Int) -> Node {
    assert(index < self.numChildren, "Node child subscript out of bounds")
    return self.children.advanced(by: index).pointee
  }
}

// MARK: Binary Search
extension Node._UnsafeHandle {
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
