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
  func test_simpleInsertion() {
    var sortedDictionary: SortedDictionary<String, Int> = [:]
    
    sortedDictionary["B"] = 1
    sortedDictionary["J"] = 1
    sortedDictionary["A"] = 1
    sortedDictionary["A"] = 2
    sortedDictionary["Z"] = 1
    sortedDictionary["E"] = 1
    sortedDictionary["Q"] = 1
    sortedDictionary["D"] = 1
    
    print(sortedDictionary.startIndex)
    
    for (key, value) in sortedDictionary {
      print("\(key): \(value)")
    }
    
    print(sortedDictionary._root)
  }
}
