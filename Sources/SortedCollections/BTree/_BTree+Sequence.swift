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
  internal struct Iterator: IteratorProtocol {
    @usableFromInline
    typealias Element = _BTree.Element
    
    /// This is a path refering to child offsets
    private var currentCursor: Path?
    
    /// Strong reference to the BTree to preserve it during iteratino.
    private let tree: _BTree
    
    internal init(startingAt btree: _BTree) {
      self.tree = btree
      self.currentCursor = Path(firstElementOf: btree)
    }
    
    @usableFromInline
    internal mutating func next() -> Element? {
      guard let cursor = currentCursor else { return nil }
      defer { currentCursor = cursor.advanced() }
      return cursor.element
    }
  }
  
  @usableFromInline
  internal func makeIterator() -> Iterator {
    return Iterator(startingAt: self)
  }
}
