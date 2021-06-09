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

final class SortedDictionaryTests: CollectionTestCase {
  func test_orderedInsertion() {
    withEvery("count", in: 0..<10) { count in
      var sortedDictionary: SortedDictionary<Int, Int> = [:]
      
      for i in 0..<count {
        sortedDictionary[i] = i
      }
      
      expectEqual(sortedDictionary.count, count)
      expectEqual(sortedDictionary.underestimatedCount, count)
      expectEqual(sortedDictionary.isEmpty, count == 0)
      
      for (i, (key, _)) in sortedDictionary.enumerated() {
        expectEqual(key, i)
      }
    }
  }
  
  func test_updateValue() {
    withEvery("count", in: 0..<10) { count in
      var sortedDictionary: SortedDictionary<Int, Int> = [:]
      
      for i in 0..<count {
        sortedDictionary[i] = i
        sortedDictionary[i] = -sortedDictionary[i]!
      }
      
      for (i, (key, value)) in sortedDictionary.enumerated() {
        expectEqual(key, i)
        expectEqual(value, -i)
      }
    }
  }
}
