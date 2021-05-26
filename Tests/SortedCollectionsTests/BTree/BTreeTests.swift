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
  
  func test_simpleEvenSplinter() {
    let keyValuePairs = [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
    ]
    
    let node = Node<Int, String>(_keyValuePairs: keyValuePairs, capacity: 2)
    var btree = BTree(_rootedAt: node)
    
    btree.insertValue("A", forKey: 1)
    
    var it = btree.makeIterator()
    print(it.next())
    print(it.next())
    print(it.next())
    print(it.next())
    
//    expectEqualElements(btree, [
//      (key: 1, value: "0"),
//      (key: 1, value: "A"),
//      (key: 2, value: "1"),
//    ])
  }
  
  func test_insertWithoutSplit() {
    let keyValuePairs = [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 3, value: "4"),
    ]
    
    let node = Node<Int, String>(_keyValuePairs: keyValuePairs, capacity: 100)
    var btree = BTree(_rootedAt: node)
    
    btree.insertValue("A", forKey: 2)
    btree.insertValue("B", forKey: 4)
    
    expectEqualElements(btree, [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 2, value: "A"),
      (key: 3, value: "4"),
      (key: 4, value: "B"),
    ])
  }
}
