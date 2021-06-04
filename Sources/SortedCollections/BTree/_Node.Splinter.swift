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
  /// Represents the result of a overfilled node's split.
  @usableFromInline
  internal struct Splinter {
    /// The former median element which should be propogated upward.
    @usableFromInline
    internal let median: Element
    
    /// The right product of the node split.
    @usableFromInline
    internal var rightChild: _Node<Key, Value>
    
    @inlinable
    @inline(__always)
    internal func toNode(from node: _Node<Key, Value>, withCapacity capacity: Int) -> _Node {
      var newNode = _Node(withCapacity: capacity, isLeaf: false)
      newNode.update { handle in
        handle.keys.initialize(to: median.key)
        handle.values.initialize(to: median.value)
        
        handle.children!.initialize(to: node)
        handle.children!.advanced(by: 1).initialize(to: self.rightChild)
        
        handle.numElements = 1
      }
      return newNode
    }
  }
}
