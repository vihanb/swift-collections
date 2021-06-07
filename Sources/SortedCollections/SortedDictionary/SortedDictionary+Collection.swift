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
  /// The number of elements in the sorted dictionary.
  /// - Complexity: O(1)
  @inlinable
  @inline(__always)
  public var count: Int { self._root.count }
  
  /// A Boolean value that indicates whether the dictionary is empty.
  @inlinable
  @inline(__always)
  public var isEmpty: Bool { self._root.isEmpty }
  
  /// The position of the first element in a nonempty dictionary.
  ///
  /// If the collection is empty, `startIndex` is equal to `endIndex`.
  ///
  /// - Complexity: O(`log n`)
  @inlinable
  public var startIndex: Index {
    Index(_index: self._root.startIndex, forDictionary: self)
  }
  
  /// The dictionary's "past the end" position---that is, the position one
  /// greater than the last valid subscript argument.
  ///
  /// If the collection is empty, `endIndex` is equal to `startIndex`.
  ///
  /// - Complexity: O(1)
  @inlinable
  public var endIndex: Index {
    Index(_index: self._root.endIndex, forDictionary: self)
  }
  
  
  @inlinable
  public func formIndex(after index: inout Index) {
    index._assertValid(for: self)
    self._root.formIndex(after: &index._index)
  }
  
  @inlinable
  public func index(after index: Index) -> Index {
    index._assertValid(for: self)
    
    var newIndex = index
    self.formIndex(after: &newIndex)
    return newIndex
  }
  
  @inlinable
  public subscript(position: Index) -> Element {
    position._assertValid(for: self)
    return self._root[position._index]
  }
}
