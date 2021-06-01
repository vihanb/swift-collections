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
    
    let node = _Node<Int, String>(_keyValuePairs: keyValuePairs, capacity: keyValuePairs.count)
    let btree = _BTree(rootedAt: node)
    
    expectEqualElements(btree, keyValuePairs)
  }
  
  func test_simpleEvenSplinter() {
    let keyValuePairs = [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
    ]
    
    let node = _Node<Int, String>(_keyValuePairs: keyValuePairs, capacity: 2)
    var btree = _BTree(rootedAt: node)
    
    btree.insertKey(1, withValue: "A")
    
    var it = btree.makeIterator()
    print(it.next() as Any)
    print(it.next() as Any)
    print(it.next() as Any)
    print(it.next() as Any)
    
//    expectEqualElements(btree, [
//      (key: 1, value: "0"),
//      (key: 1, value: "A"),
//      (key: 2, value: "1"),
//    ])
  }
  
  func test_23treeSplitting() {
    let node = _Node<Int, String>(_keyValuePairs: [
      (key: 2, value: "0"),
      (key: 4, value: "1"),
    ], capacity: 2)
    
    var btree = _BTree(rootedAt: node)
    
    print(btree)
    btree.insertKey(3, withValue: "A")
    btree.insertKey(4, withValue: "B")
  }
  
  func test_splitMedianSplinterEven() {
    let node = _Node<Int, Void>(_keyValuePairs: [
      (key: 1, value: ()),
      (key: 2, value: ()),
      (key: 3, value: ()),
      (key: 5, value: ()),
      (key: 6, value: ()),
      (key: 7, value: ()),
    ], capacity: 6)
    
    var btree = _BTree(rootedAt: node)
    print(btree)
    btree.insertKey(4, withValue: ())
    print(btree)
  }
  
  func test_splitRightSplinterEven() {
    let node = _Node<Int, Void>(_keyValuePairs: [
      (key: 1, value: ()),
      (key: 2, value: ()),
      (key: 3, value: ()),
      (key: 4, value: ()),
      (key: 5, value: ()),
      (key: 7, value: ()),
    ], capacity: 6)
    
    var btree = _BTree(rootedAt: node)
    print(btree)
    btree.insertKey(6, withValue: ())
    print(btree)
  }
  
  func test_interactiveTreeTest() {
    let node = _Node<Int, Void>(_keyValuePairs: [
      (key: 5, value: ()),
      (key: 10, value: ()),
    ], capacity: 2)
    
    var btree = _BTree(rootedAt: node)
    print(btree)
    
    while let line = readLine(strippingNewline: true) {
      if let newNum = Int(line) {
        btree.insertKey(newNum, withValue: ())
        print(btree)
      }
    }
  }
  
  func test_insertWithoutSplit() {
    let keyValuePairs = [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 3, value: "4"),
    ]
    
    let node = _Node<Int, String>(_keyValuePairs: keyValuePairs, capacity: 100)
    var btree = _BTree(rootedAt: node)
    debugPrint(btree)
    
    btree.insertKey(2, withValue: "A")
    btree.insertKey(4, withValue: "B")
    debugPrint(btree)
    
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
