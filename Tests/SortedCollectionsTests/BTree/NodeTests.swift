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
    let nodeA = Node<Int, String>(_keyValuePairs: [], capacity: 5)
    let nodeB = nodeA
//    _ = nodeB.insertValue("A", forKey: 1)
    expectEqual(nodeA.count, 0)
    expectEqual(nodeB.count, 1)
  }
//
//  func test_insertion() {
//    let node = Node<Int, String>(_keyValuePairs: [
//      (key: 1, value: "0"),
//      (key: 2, value: "1"),
//      (key: 2, value: "2"),
//      (key: 2, value: "3"),
//      (key: 2, value: "4"),
//      (key: 3, value: "5"),
//    ], capacity: 100)
//
//    _ = node.insertValue("A", forKey: 0)
//    _ = node.insertValue("B", forKey: 2)
//    _ = node.insertValue("C", forKey: 3)
//    _ = node.insertValue("D", forKey: 4)
//    print(node)
//  }
  
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
