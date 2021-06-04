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

extension SortedDictionary: Collection {
  /// The position of the first element in a nonempty dictionary.
  ///
  /// If the collection is empty, `startIndex` is equal to `endIndex`.
  ///
  /// - Complexity: O(`log n`)
  public var startIndex: Index {
    Index(_path: self._root.startIndex, forDictionary: self)
  }
  
  /// The dictionary's "past the end" position---that is, the position one
  /// greater than the last valid subscript argument.
  ///
  /// If the collection is empty, `endIndex` is equal to `startIndex`.
  ///
  /// - Complexity: O(1)
  public var endIndex: Index {
    Index(_path: self._root.endIndex, forDictionary: self)
  }
  
  public func index(after index: Index) -> Index {
    guard let path = index._path, index._root === self._root.root.storage else {
      preconditionFailure("Attempt to operate on invalid Dictionary index.")
    }
    
    return Index(_path: self._root.index(after: path), forDictionary: self)
  }
  
  public subscript(position: Index) -> Element {
    precondition(position._root === self._root.root.storage && position._path != nil,
                 "Attempting to access Dictionary elements using an invalid index.")
    return position._path!.element
  }
}
