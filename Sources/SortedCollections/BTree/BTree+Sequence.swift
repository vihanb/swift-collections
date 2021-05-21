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

extension BTree: Sequence {
  typealias Iterator = NodeIterator
  
  internal struct NodeIterator: IteratorProtocol {
    typealias Element = BTree.Element
    
    /// This is a path refering to child offsets
    private var currentCursor: Cursor?
    
    internal init(startingAt btree: BTree) {
      self.currentCursor = Cursor(firstElementOf: btree)
    }
    
    mutating func next() -> Element? {
      guard let cursor = currentCursor else { return nil }
      defer { currentCursor = cursor.advanced() }
      return cursor.element
    }
  }
  
  @usableFromInline
  internal func makeIterator() -> NodeIterator {
    return NodeIterator(startingAt: self)
  }
}
