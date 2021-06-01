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


extension _BTree: Sequence {
  @usableFromInline
  typealias Iterator = NodeIterator
  
  @usableFromInline
  internal struct NodeIterator: IteratorProtocol {
    @usableFromInline
    typealias Element = _BTree.Element
    
    /// This is a path refering to child offsets
    private var currentCursor: Path?
    
    internal init(startingAt btree: _BTree) {
      self.currentCursor = Path(firstElementOf: btree)
    }
    
    @usableFromInline
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
