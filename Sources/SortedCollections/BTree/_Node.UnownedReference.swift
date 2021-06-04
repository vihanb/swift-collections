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

/// Represents an unowned reference to a Node
extension _Node {
  @usableFromInline
  internal struct _UnownedReference {
  
    @usableFromInline
    internal unowned let keys: Buffer<Key>
    
    @usableFromInline
    internal unowned let values: Buffer<Value>
    
    @usableFromInline
    internal unowned let children: Buffer<_Node<Key, Value>>?
    
    /// The total number of key-value pairs this node can store
    @usableFromInline
    internal var capacity: Int
    
    @inlinable
    internal init(referencing node: _Node) {
      self.keys = unsafeDowncast(node.keys.buffer.buffer, to: <#T##T.Type#>)
      self.values = node.keys.buffer.buffer
    }
  }
}
