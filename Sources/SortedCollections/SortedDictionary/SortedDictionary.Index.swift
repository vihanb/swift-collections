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

extension SortedDictionary {
  /// Returns the index for a given key, if it exists
  /// - Complexity: O(`log n`)
  public func index(forKey key: Key) -> Index? {
    if let path = self._root.findFirstKey(key) {
      return Index(_index: _Tree.Index(path), forDictionary: self)
    } else {
      return nil
    }
  }
  
  /// The position of an element within a sorted dictionary
  public struct Index {
    @usableFromInline
    internal var _index: _Tree.Index
    
    @usableFromInline
    internal weak var _root: _Tree.Node.Storage?
    
    @inlinable
    @inline(__always)
    internal init(_index: _Tree.Index, forDictionary dictionary: SortedDictionary) {
      self._root = dictionary._root.root.storage
      self._index = _index
      // TODO: add age property
    }
    
    /// Asserts the index is valid before proceeding
    @inlinable
    internal func _assertValid() {
      precondition(self._root != nil, "Attempt to use an invalid SortedDictionary index.")
    }
  }
}

// MARK: Equatable
extension SortedDictionary.Index: Equatable {
  // TODO: Potentially validate if lhs & rhs aren't pointing to deallocated dictionaries.
  public static func ==(lhs: SortedDictionary.Index, rhs: SortedDictionary.Index) -> Bool {
    lhs._assertValid()
    rhs._assertValid()
    precondition(lhs._root === rhs._root, "Comparing indexes from different dictionaries.")
    return lhs._index == rhs._index
  }
}

// MARK: Comparable
extension SortedDictionary.Index: Comparable {
  public static func <(lhs: SortedDictionary.Index, rhs: SortedDictionary.Index) -> Bool {
    lhs._assertValid()
    rhs._assertValid()
    precondition(lhs._root === rhs._root, "Comparing indexes from different dictionaries.")
    return lhs._index < rhs._index
  }
}
