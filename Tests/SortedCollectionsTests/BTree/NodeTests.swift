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

func nodeFromKeys(_ keys: [Int], capacity: Int) -> _Node<Int, Int> {
  let kvPairs = keys.map { (key: $0, value: $0 * 2) }
  return _Node<Int, Int>(_keyValuePairs: kvPairs, capacity: capacity)
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
  _ body: (_Node<Int, Int>, [Int], Int) throws -> Void
) rethrows {
  let possibleShifts = keys - duplicates + 1
  try withEvery("shift", in: 0..<possibleShifts) { shift in
    let repeatedKey = shift
    
    var values = Array(0..<shift)
    values.append(contentsOf: repeatElement(repeatedKey, count: duplicates))
    values.append(contentsOf: (repeatedKey + 1)..<(repeatedKey + 1 + keys - values.count))
    
    
    let node = nodeFromKeys(values, capacity: capacity)
    
    try body(node, values, repeatedKey)
  }
}

func expectInsertionInTree(
  capacity: Int,
  tree: NodeTemplate,
  inserting key: Int,
  toEqual refTree: NodeTemplate) {
  var node = tree.toNode(ofCapacity: capacity)
  
  if let splinter = node.update({ $0.insertElement((key: key, value: key * 2)) }) {
    node = splinter.toNode(from: node, withCapacity: capacity)
  }
  
  let refMatches = refTree.matches(node)
  if !refMatches {
    print("Expected: ")
    print(_BTree(rootedAt: refTree.toNode(ofCapacity: capacity)))
    print("Instead got: ")
    print(_BTree(rootedAt: node))
  }
  expectTrue(refTree.matches(node))
}

final class NodeTests: CollectionTestCase {
  // MARK: Median Leaf Node Insertion
  func test_medianLeafInsertion() {
    expectInsertionInTree(
      capacity: 2,
      tree: tree { 0; 2 },
      inserting: 1,
      toEqual: tree {
        tree { 0 }
        1
        tree { 2 }
      }
    )
    
    expectInsertionInTree(
      capacity: 4,
      tree: tree { 0; 1; 3; 4 },
      inserting: 2,
      toEqual: tree {
        tree { 0; 1 }
        2
        tree { 3; 4 }
      }
    )
    
    expectInsertionInTree(
      capacity: 5,
      tree: tree { 0; 1; 3; 4; 5 },
      inserting: 2,
      toEqual: tree {
        tree { 0; 1 }
        2
        tree { 3; 4; 5 }
      }
    )
  }
  
  // MARK: Median Internal Node Insertion
  func test_medianInternalInsertion() {
    expectInsertionInTree(
      capacity: 2,
      tree: tree {
        tree { 0; 1 }
        2
        tree { 3; 5 }
        6
        tree { 7; 8 }
      },
      inserting: 4,
      toEqual: tree {
        tree {
          tree { 0; 1 }
          2
          tree { 3 }
        }
        4
        tree {
          tree { 5 }
          6
          tree { 7; 8 }
        }
      }
    )
    
    expectInsertionInTree(
      capacity: 3,
      tree: tree {
        tree { 0; 1; 2 }
        3
        tree { 4; 6; 7 }
        8
        tree { 9; 10; 11 }
        12
        tree { 13; 14; 15 }
      },
      inserting: 5,
      toEqual: tree {
        tree {
          tree { 0; 1; 2 }
          3
          tree { 4 }
        }
        5
        tree {
          tree { 6; 7 }
          8
          tree { 9; 10; 11 }
          12
          tree { 13; 14; 15 }
        }
      }
    )
    
    expectInsertionInTree(
      capacity: 4,
      tree: tree {
        tree { 0; 1; 2; 4 }
        5
        tree { 6; 7; 8; 9 }
        10
        tree { 11; 12; 14; 15 }
        16
        tree { 17; 18; 19; 20 }
        21
        tree { 22; 23; 24; 25 }
      },
      inserting: 13,
      toEqual: tree {
        tree {
          tree { 0; 1; 2; 4 }
          5
          tree { 6; 7; 8; 9 }
          10
          tree { 11; 12 }
        }
        13
        tree {
          tree { 14; 15 }
          16
          tree { 17; 18; 19; 20 }
          21
          tree { 22; 23; 24; 25 }
        }
      }
    )
    
    expectInsertionInTree(
      capacity: 5,
      tree: tree {
        tree { 0; 1; 2; 4; 5 }
        6
        tree { 7; 8; 9; 10; 11 }
        12
        tree { 13; 14; 16; 17; 18 }
        19
        tree { 20; 21; 22; 23; 24 }
        25
        tree { 26; 27; 28; 29; 30 }
        31
        tree { 32; 33; 34; 35; 36 }
      },
      inserting: 15,
      toEqual: tree {
        tree {
          tree { 0; 1; 2; 4; 5 }
          6
          tree { 7; 8; 9; 10; 11 }
          12
          tree { 13; 14 }
        }
        15
        tree {
          tree { 16; 17; 18 }
          19
          tree { 20; 21; 22; 23; 24 }
          25
          tree { 26; 27; 28; 29; 30 }
          31
          tree { 32; 33; 34; 35; 36 }
        }
      }
    )
  }
  
  // MARK: Right Leaf Insertion
  func test_rightLeafInsertion() {
    expectInsertionInTree(
      capacity: 2,
      tree: tree { 1; 2 },
      inserting: 3,
      toEqual: tree {
        tree { 1 }
        2
        tree { 3 }
      }
    )
    
    expectInsertionInTree(
      capacity: 3,
      tree: tree { 1; 2; 4 },
      inserting: 3,
      toEqual: tree {
        tree { 1 }
        2
        tree { 3; 4 }
      }
    )
    
    expectInsertionInTree(
      capacity: 4,
      tree: tree { 0; 1; 2; 4 },
      inserting: 3,
      toEqual: tree {
        tree { 0; 1 }
        2
        tree { 3; 4 }
      }
    )
    
    expectInsertionInTree(
      capacity: 5,
      tree: tree { 0; 1; 2; 3; 5 },
      inserting: 4,
      toEqual: tree {
        tree { 0; 1 }
        2
        tree { 3; 4; 5 }
      }
    )
  }
  
  // MARK: Right Internal Node Insertion
  func test_rightInternalNodeInsertion() {
    expectInsertionInTree(
      capacity: 2,
      tree: tree {
        tree { 0; 1 }
        2
        tree { 3; 4 }
        5
        tree { 6; 7 }
      },
      inserting: 8,
      toEqual: tree {
        tree {
          tree { 0; 1 }
          2
          tree { 3; 4 }
        }
        5
        tree {
          tree { 6 }
          7
          tree { 8 }
        }
      }
    )
    
    expectInsertionInTree(
      capacity: 3,
      tree: tree {
        tree { 0; 1; 2 }
        3
        tree { 4; 5; 6 }
        7
        tree { 8; 9; 10 }
        11
        tree { 12; 13; 15 }
      },
      inserting: 14,
      toEqual: tree {
        tree {
          tree { 0; 1; 2 }
          3
          tree { 4; 5; 6 }
        }
        7
        tree {
          tree { 8; 9; 10 }
          11
          tree { 12 }
          13
          tree { 14; 15 }
        }
      }
    )

    expectInsertionInTree(
      capacity: 4,
      tree: tree {
        tree { 0; 1; 2; 4 }
        5
        tree { 6; 7; 8; 9 }
        10
        tree { 11; 12; 13; 14 }
        15
        tree { 16; 17; 18; 19 }
        20
        tree { 21; 22; 23; 25 }
      },
      inserting: 24,
      toEqual: tree {
        tree {
          tree { 0; 1; 2; 4 }
          5
          tree { 6; 7; 8; 9 }
          10
          tree { 11; 12; 13; 14 }
        }
        15
        tree {
          tree { 16; 17; 18; 19 }
          20
          tree { 21; 22 }
          23
          tree { 24; 25 }
        }
      }
    )

    expectInsertionInTree(
      capacity: 5,
      tree: tree {
        tree { 0; 1; 2; 4; 5 }
        6
        tree { 7; 8; 9; 10; 11 }
        12
        tree { 13; 14; 15; 16; 17 }
        18
        tree { 19; 20; 21; 22; 23 }
        24
        tree { 25; 26; 27; 28; 29 }
        30
        tree { 31; 32; 33; 34; 36 }
      },
      inserting: 35,
      toEqual: tree {
        tree {
          tree { 0; 1; 2; 4; 5 }
          6
          tree { 7; 8; 9; 10; 11 }
          12
          tree { 13; 14; 15; 16; 17 }
        }
        18
        tree {
          tree { 19; 20; 21; 22; 23 }
          24
          tree { 25; 26; 27; 28; 29 }
          30
          tree { 31; 32 }
          33
          tree { 34; 35; 36 }
        }
      }
    )
  }
  
  // MARK: Left Leaf Insertion
  func test_leftLeafInsertion() {
    expectInsertionInTree(
      capacity: 2,
      tree: tree { 1; 2 },
      inserting: 0,
      toEqual: tree {
        tree { 0 }
        1
        tree { 2 }
      }
    )
    
    expectInsertionInTree(
      capacity: 3,
      tree: tree { 1; 2; 3 },
      inserting: 0,
      toEqual: tree {
        tree { 0; 1 }
        2
        tree { 3 }
      }
    )
    
    expectInsertionInTree(
      capacity: 4,
      tree: tree { 0; 2; 3; 4 },
      inserting: 1,
      toEqual: tree {
        tree { 0; 1 }
        2
        tree { 3; 4 }
      }
    )
    
    expectInsertionInTree(
      capacity: 5,
      tree: tree { 0; 2; 3; 4; 5 },
      inserting: 1,
      toEqual: tree {
        tree { 0; 1; 2 }
        3
        tree { 4; 5 }
      }
    )
  }
  
  // MARK: Left Internal Node Insertion
  func test_leftInternalNodeInsertion() {
    expectInsertionInTree(
      capacity: 2,
      tree: tree {
        tree { 1; 2 }
        3
        tree { 4; 5 }
        6
        tree { 7; 8 }
      },
      inserting: 0,
      toEqual: tree {
        tree {
          tree { 0 }
          1
          tree { 2 }
        }
        3
        tree {
          tree { 4; 5 }
          6
          tree { 7; 8 }
        }
      }
    )
    
    expectInsertionInTree(
      capacity: 3,
      tree: tree {
        tree { 1; 2; 3 }
        4
        tree { 5; 6; 7 }
        8
        tree { 9; 10; 11 }
        12
        tree { 13; 14; 15 }
      },
      inserting: 0,
      toEqual: tree {
        tree {
          tree { 0; 1 }
          2
          tree { 3 }
          4
          tree { 5; 6; 7 }
        }
        8
        tree {
          tree { 9; 10; 11 }
          12
          tree { 13; 14; 15 }
        }
      }
    )

    expectInsertionInTree(
      capacity: 4,
      tree: tree {
        tree { 0; 2; 3; 4 }
        5
        tree { 6; 7; 8; 9 }
        10
        tree { 11; 12; 13; 14 }
        15
        tree { 16; 17; 18; 19 }
        20
        tree { 21; 22; 23; 24 }
      },
      inserting: 1,
      toEqual: tree {
        tree {
          tree { 0; 1 }
          2
          tree { 3; 4 }
          5
          tree { 6; 7; 8; 9 }
        }
        10
        tree {
          tree { 11; 12; 13; 14 }
          15
          tree { 16; 17; 18; 19 }
          20
          tree { 21; 22; 23; 24 }
        }
      }
    )

    expectInsertionInTree(
      capacity: 5,
      tree: tree {
        tree { 0; 2; 3; 4; 5 }
        6
        tree { 7; 8; 9; 10; 11 }
        12
        tree { 13; 14; 15; 16; 17 }
        18
        tree { 19; 20; 21; 22; 23 }
        24
        tree { 25; 26; 27; 28; 29 }
        30
        tree { 31; 32; 33; 34; 35 }
      },
      inserting: 1,
      toEqual: tree {
        tree {
          tree { 0; 1; 2 }
          3
          tree { 4; 5 }
          6
          tree { 7; 8; 9; 10; 11 }
          12
          tree { 13; 14; 15; 16; 17 }
        }
        18
        tree {
          tree { 19; 20; 21; 22; 23 }
          24
          tree { 25; 26; 27; 28; 29 }
          30
          tree { 31; 32; 33; 34; 35 }
        }
      }
    )
  }
  
  func test_singleNodeInsertion() {
    withEvery("capacity", in: 2..<10) { capacity in
      withEvery("count", in: 0..<capacity) { count in
        withEvery("position", in: 0...count) { position in
          
          let keys = (0..<count).map({ ($0 + 1) * 2 })
          
          var node = nodeFromKeys(keys, capacity: capacity)
          var array = Array(keys)
          
          let newKey = position * 2 + 1
          
          let splinter = node.update { $0.insertElement((key: newKey, value: newKey * 2)) }
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
  
  func test_singleTotalElementCounts() {
    withEvery("capacity", in: 2..<10) { capacity in
      withEvery("count", in: 0..<capacity) { count in
        withEvery("position", in: 0...count) { position in
          
          let keys = (0..<count).map({ ($0 + 1) * 2 })
          
          var node = nodeFromKeys(keys, capacity: capacity)
          var array = Array(keys)
          
          let newKey = position * 2 + 1
          
          let splinter = node.update { $0.insertElement((key: newKey, value: newKey * 2)) }
          insertSortedValue(newKey, into: &array)
          
          expectNil(splinter)
          node.read { handle in
            expectEqual(handle.numTotalElements, count + 1)
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
}
