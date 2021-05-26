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


final class NodeTests: CollectionTestCase {
  func test_COW() {
    #if COLLECTIONS_INTERNAL_CHECKS
    expectEqual(1, 1)
    #else
    expectEqual(1, 0)
    #endif
    
    let nodeA = Node<Int, String>(_keyValuePairs: [], capacity: 5)
//    let nodeB = nodeA
//    _ = nodeB.insertValue("A", forKey: 1)
//    expectEqual(nodeA.count, 0)
//    expectEqual(nodeB.count, 1)
  }
//
  
  func test_23treeSplitting() {
    var node = Node<Int, String>(_keyValuePairs: [
      (key: 2, value: "0"),
      (key: 4, value: "1"),
    ], capacity: 2)
    
    node.update { handle in
      _ = handle.insertValue("A", forKey: 3)
    }
  }
  
  func test_singleNodeInsertion() {
    var node = Node<Int, String>(_keyValuePairs: [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 2, value: "4"),
      (key: 3, value: "5"),
    ], capacity: 100)

    node.update { handle in
      _ = handle.insertValue("A", forKey: 0)
      _ = handle.insertValue("B", forKey: 2)
      _ = handle.insertValue("C", forKey: 3)
      _ = handle.insertValue("D", forKey: 4)
    }
    
    node.read { handle in
      expectEqual(handle.numKeys, 10)
      expectEqual(handle.numValues, 10)
      expectEqual(handle.numChildren, 0)
    }
    
    expectEqualElements(BTree(_rootedAt: node), [
      (key: 0, value: "A"),
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 2, value: "4"),
      (key: 2, value: "B"),
      (key: 3, value: "5"),
      (key: 3, value: "C"),
      (key: 4, value: "D"),
    ])
  }
  
  func test_binarySearchMiddle() {
    let node = Node<Int, String>(_keyValuePairs: [
      (key: 0, value: "0"),
      (key: 2, value: "1"),
      (key: 4, value: "2"),
      (key: 6, value: "3"),
      (key: 8, value: "4"),
    ], capacity: 100)
    
    node.read { handle in
      expectEqual(handle.firstIndex(of: 3), 2)
      expectEqual(handle.lastIndex(of: 3), 2)
    }
  }
  
  func test_binarySearchOdd() {
    let node = Node<Int, String>(_keyValuePairs: [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 3, value: "4"),
    ], capacity: 100)
    
    node.read { handle in
      expectEqual(handle.firstIndex(of: 1), 0)
      expectEqual(handle.lastIndex(of: 1), 1)
      
      expectEqual(handle.firstIndex(of: 2), 1)
      expectEqual(handle.lastIndex(of: 2), 4)
      
      expectEqual(handle.firstIndex(of: 3), 4)
      expectEqual(handle.lastIndex(of: 3), 5)
      
      expectEqual(handle.firstIndex(of: 0), 0)
      expectEqual(handle.lastIndex(of: 0), 0)
      expectEqual(handle.firstIndex(of: 4), 5)
      expectEqual(handle.lastIndex(of: 4), 5)
    }
  }
  
  func test_binarySearchEven() {
    let node = Node<Int, String>(_keyValuePairs: [
      (key: 1, value: "0"),
      (key: 2, value: "1"),
      (key: 2, value: "2"),
      (key: 2, value: "3"),
      (key: 2, value: "4"),
      (key: 3, value: "5"),
    ], capacity: 100)
    
    node.read { handle in
      expectEqual(handle.firstIndex(of: 1), 0)
      expectEqual(handle.lastIndex(of: 1), 1)
      
      expectEqual(handle.firstIndex(of: 2), 1)
      expectEqual(handle.lastIndex(of: 2), 5)
      
      expectEqual(handle.firstIndex(of: 3), 5)
      expectEqual(handle.lastIndex(of: 3), 6)
      
      expectEqual(handle.firstIndex(of: 0), 0)
      expectEqual(handle.lastIndex(of: 0), 0)
      expectEqual(handle.firstIndex(of: 4), 6)
      expectEqual(handle.lastIndex(of: 4), 6)
    }
  }
}
