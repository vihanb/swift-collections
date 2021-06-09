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

func btreeFromKeys<S: Sequence>(
  _ keys: S
) -> _BTree<Int, Int> where S.Element == Int {
  var tree = _BTree<Int, Int>(capacity: 3)
  for (i, key) in keys.enumerated() {
    tree.insertKey(key, withValue: i)
  }
  return tree
}


func withEveryBTree(
  upTo capacity: Int,
  _ body: (_BTree<Int, Int>, [(key: Int, value: Int)]) throws -> Void
) rethrows {
  try withEvery("capacity", in: 0..<10) { capacity in
    let elements = (0...capacity).map { (key: $0, value: $0) }
    var tree = _BTree<Int, Int>(capacity: 3)
    for (key, value) in elements {
      tree.insertKey(key, withValue: value)
    }
    try body(tree, elements)
  }
}

final class BTreeTests: CollectionTestCase {
  func test_indexedAccess() {
    var btree = _BTree<Int, Void>(capacity: 2)
    let NUM_ELEMS = 10
    for i in 0..<NUM_ELEMS {
      print(btree)
      btree.insertKey(i, withValue: ())
    }
    
    for i in 0..<NUM_ELEMS {
      let path = btree.pathToElement(at: i)
      expectEqual(path.element.key, i)
    }
  }
  
  func test_bidirectionalCollection() {
    withEveryBTree(upTo: 10) { (tree, elements) in
      checkBidirectionalCollection(
        tree, expectedContents: elements, by: { $0.key == $1.key && $0.value == $1.value })
    }
  }
  
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
    
    expectEqualElements(btree.root.toArray(), keyValuePairs)
  }
  
  func test_simpleEvenSplinter() {
    let keyValuePairs = [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
    ]
    
    let node = _Node<Int, String>(_keyValuePairs: keyValuePairs, capacity: 2)
    var btree = _BTree(rootedAt: node)
    
    btree.insertKey(1, withValue: "A")
    
    
  }
  
  func test_23treeSplitting() {
    let node = _Node<Int, String>(_keyValuePairs: [
      (key: 2, value: "0"),
      (key: 4, value: "1"),
    ], capacity: 2)
    
    var btree = _BTree(rootedAt: node)
    
    btree.insertKey(3, withValue: "A")
    btree.insertKey(4, withValue: "B")
    
    expectEqualElements(btree.root.toArray(), [
      (key: 2, value: "0"),
      (key: 3, value: "A"),
      (key: 4, value: "1"),
      (key: 4, value: "B"),
    ])
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
  
//  func test_interactiveTreeTest() {
//    let node = _Node<Int, Void>(_keyValuePairs: [
//      (key: 5, value: ()),
//      (key: 10, value: ()),
//    ], capacity: 2)
//
//    var btree = _BTree(rootedAt: node)
//    print(btree)
//
//    while let line = readLine(strippingNewline: true) {
//      if let newNum = Int(line) {
//        btree.insertKey(newNum, withValue: ())
//        print(btree)
//      }
//    }
//  }
  
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
    
    btree.insertKey(2, withValue: "A")
    btree.insertKey(4, withValue: "B")
    
    expectEqualElements(btree.root.toArray(), [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 2, value: "A"),
      (key: 3, value: "4"),
      (key: 4, value: "B"),
    ])
  }
  
  func test_pathIterator() {
    var btree = _BTree<Int, ()>(capacity: 4)
    for i in 0..<100 {
      btree.insertKey(i, withValue: ())
    }
    
    let btreeElems = Array(btree)
//    expectEqualElements(btreeElems, btree.root.toArray())
  }
}
