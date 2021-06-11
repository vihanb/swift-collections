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
  }
}
