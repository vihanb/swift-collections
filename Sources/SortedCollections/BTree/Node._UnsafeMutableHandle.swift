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
  internal struct _UnsafeMutableHandle {
    @usableFromInline
    internal let read: _UnsafeHandle
    
    // MARK: Mutable Properties
    @inlinable
    @inline(__always)
    internal var keyHeader: UnsafeMutablePointer<_BufferHeader> { UnsafeMutablePointer(mutating: self.read.keyHeader) }
    
    @inlinable
    @inline(__always)
    internal var valueHeader: UnsafeMutablePointer<_BufferHeader> { UnsafeMutablePointer(mutating: self.read.valueHeader) }
    
    @inlinable
    @inline(__always)
    internal var childrenHeader: UnsafeMutablePointer<_BufferHeader> { UnsafeMutablePointer(mutating: self.read.childrenHeader) }
    
    @inlinable
    @inline(__always)
    internal var keys: UnsafeMutablePointer<Key> { UnsafeMutablePointer(mutating: self.read.keys) }
    
    @inlinable
    @inline(__always)
    internal var values: UnsafeMutablePointer<Value> { UnsafeMutablePointer(mutating: self.read.values) }
    
    @inlinable
    @inline(__always)
    internal var children: UnsafeMutablePointer<Node<Key, Value>> { UnsafeMutablePointer(mutating: self.read.children) }
    
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
    
    @usableFromInline
    internal init(_ unsafeHandle: _UnsafeHandle) {
      self.read = unsafeHandle
    }
  }
}

// MARK: Node Mutations
extension Node._UnsafeMutableHandle {
  @usableFromInline
  typealias Splinter = (median: Node.Element, rightChild: Node<Key, Value>)
  
//  @inlinable
//  internal func insertValue(_ value: Value, forKey key: Key) -> Splinter {
//    self.read.lastIndex(of: key)
//  }
  
}
