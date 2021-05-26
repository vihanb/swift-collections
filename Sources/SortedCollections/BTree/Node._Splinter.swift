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
  /// Represents the result of a overfilled node's split.
  @usableFromInline
  internal struct _Splinter {
    /// The former median element which should be propogated upward.
    @usableFromInline
    internal let median: Element
    
    // TODO: will swift optimize-away this property if unused?
    /// The left product of the node split.
    @usableFromInline
    internal var leftChild: Node<Key, Value>
    
    /// The right product of the node split.
    @usableFromInline
    internal var rightChild: Node<Key, Value>
    
    @inlinable
    @inline(__always)
    internal func toNode(withCapacity capacity: Int) -> Node {
      var node = Node(withCapacity: capacity)
      node.update { handle in
        handle.keys.initialize(to: median.key)
        handle.values.initialize(to: median.value)
        handle.numKeys = 1
        handle.numValues = 1
        
        handle.children.initialize(to: self.leftChild)
        handle.children.advanced(by: 1).initialize(to: self.rightChild)
        handle.numChildren = 2
      }
      return node
    }
  }
}
