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

import CollectionsTestSupport
@_spi(Testing) @testable import SortedCollections


final class BTreeTests: CollectionTestCase {
  func test_iterator() {
    let keyValuePairs = [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 3, value: "4"),
    ]
    
    let node = Node<Int, String>(_keyValuePairs: keyValuePairs, capacity: keyValuePairs.count)
    let btree = BTree(_rootedAt: node)
    
    expectEqualElements(btree, keyValuePairs)
  }
}
