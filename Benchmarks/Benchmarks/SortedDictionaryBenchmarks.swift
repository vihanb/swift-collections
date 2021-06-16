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

import CollectionsBenchmark
import SortedCollections

extension Benchmark {
  public mutating func addSortedDictionaryBenchmarks() {
    self.add(
      title: "SortedDictionary<Int, Int> init(uniqueKeysWithValues:)",
      input: [Int].self
    ) { input in
      let keysAndValues = input.map { ($0, 2 * $0) }
      return { timer in
        blackHole(SortedDictionary(uniqueKeysWithValues: keysAndValues))
      }
    }
    
    self.add(
      title: "SortedDictionary<Int, Int>._Node",
      input: [Int].self
    ) { input in
      return { timer in
        var node = _Node<Int, Int>(withCapacity: 1050, isLeaf: true)
        for key in input {
          let splinter = node.update { handle in
            handle.insertElement((key: key, value: key * 2))
          }
          
          if let splinter = splinter {
            node = splinter.toNode(from: node, withCapacity: 1050)
          }
        }
        blackHole(node)
      }
    }
  }
}
