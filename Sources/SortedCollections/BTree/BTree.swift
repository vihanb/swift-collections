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

// Totally arbitrary node capacity for BTree
let BTREE_NODE_CAPACITY = 100

internal struct BTree<Key: Comparable, Value> {
  /// The underlying node behind this local BTree
  private var root: Node<Key, Value>
  
  /// The total number of elements in every node in this BTree.
  internal var count: Int
  
  internal init() {
    self.root = Node(withCapacity: BTREE_NODE_CAPACITY)
    self.count = 0
  }
  
  mutating func insertValue(_ value: Value, forKey key: Key) {
    root.update { handle in
      if let splinter = handle.insertValue(value, forKey: key) {
        self.root = root.
      }
    }
  }
}
