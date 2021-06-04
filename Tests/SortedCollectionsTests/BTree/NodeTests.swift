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

func nodeFromKeys(_ keys: [Int], capacity: Int) -> _Node<Int, Void> {
  let kvPairs = keys.map { (key: $0, value: ()) }
  return _Node<Int, Void>(_keyValuePairs: kvPairs, capacity: capacity)
}

func insertSortedValue(_ value: Int, into array: inout [Int]) {
  var insertionIndex = 0
  while insertionIndex < array.count {
    if array[insertionIndex] > value {
      break
    }
    insertionIndex += 1
  }
  array.insert(value, at: insertionIndex)
}

func findFirstIndexOf(_ value: Int, in array: [Int]) -> Int {
  var index = 0
  while index < array.count {
    if array[index] >= value {
      break
    }
    index += 1
  }
  return index
}

func findLastIndexOf(_ value: Int, in array: [Int]) -> Int {
  var index = 0
  while index < array.count {
    if array[index] > value {
      break
    }
    index += 1
  }
  return index
}

/// Generates all shifts of a duplicate run in a node of capacity N.
/// - Parameters:
///   - capacity: Total capacity of node.
///   - keys: The number filled keys in the node.
///   - duplicates: The number of duplicates. Must be greater than or equal to 1
/// - Returns: The duplicated key.
func withEveryNode(
  ofCapacity capacity: Int,
  keys: Int,
  duplicates: Int,
  _ body: (_Node<Int, Void>, [Int], Int) throws -> Void
) rethrows {
  let possibleShifts = keys - duplicates + 1
  try withEvery("shift", in: 0..<possibleShifts) { shift in
    let repeatedKey = shift
    
    // [0 1 2 2 2 3]
    
    var values = Array(0..<shift)
    values.append(contentsOf: repeatElement(repeatedKey, count: duplicates))
    values.append(contentsOf: (repeatedKey + 1)..<(repeatedKey + 1 + keys - values.count))
    
    
    let node = nodeFromKeys(values, capacity: capacity)
    
    try body(node, values, repeatedKey)
  }
}

final class NodeTests: CollectionTestCase {
  func test_singleNodeInsertion() {
    withEvery("capacity", in: 2..<10) { capacity in
      withEvery("count", in: 0..<capacity) { count in
        withEvery("position", in: 0...count) { position in
          
          let keys = (0..<count).map({ ($0 + 1) * 2 })
          
          var node = nodeFromKeys(keys, capacity: capacity)
          var array = Array(keys)
          
          let newKey = position * 2 + 1
          
          let splinter = node.update { $0.insertElement((key: newKey, value: ())) }
          insertSortedValue(newKey, into: &array)
          
          expectNil(splinter)
          node.read { handle in
            let keys = UnsafeBufferPointer(start: handle.keys, count: handle.numElements)
            expectEqualElements(keys, array)
          }
        }
      }
    }
  }
  
  func test_firstIndexOfDuplicates() {
    withEvery("capacity", in: 2..<10) { capacity in
      withEvery("keys", in: 0...capacity) { keys in
        withEvery("duplicates", in: 0...keys) { duplicates in
          withEveryNode(ofCapacity: capacity, keys: keys, duplicates: duplicates) { node, array, duplicatedKey  in
            node.read { handle in
              expectEqual(
                handle.firstIndex(of: duplicatedKey),
                findFirstIndexOf(duplicatedKey, in: array)
              )
            }
          }
        }
      }
    }
  }
  
  func test_lastIndexOfDuplicates() {
    withEvery("capacity", in: 2..<10) { capacity in
      withEvery("keys", in: 0...capacity) { keys in
        withEvery("duplicates", in: 0...keys) { duplicates in
          withEveryNode(ofCapacity: capacity, keys: keys, duplicates: duplicates) { node, array, duplicatedKey  in
            node.read { handle in
              expectEqual(
                handle.lastIndex(of: duplicatedKey),
                findLastIndexOf(duplicatedKey, in: array)
              )
            }
          }
        }
      }
    }
  }
  
  func test_binarySearchMiddle() {
    let node = _Node<Int, String>(_keyValuePairs: [
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
    let node = _Node<Int, String>(_keyValuePairs: [
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
    let node = _Node<Int, String>(_keyValuePairs: [
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
