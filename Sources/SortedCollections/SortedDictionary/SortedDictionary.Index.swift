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
  @inlinable
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
    
    @usableFromInline
    internal let _age: Int32
    
    @inlinable
    @inline(__always)
    internal init(_index: _Tree.Index, forDictionary dictionary: SortedDictionary) {
      self._root = dictionary._root.root.storage
      self._index = _index
      self._age = dictionary._age
    }
    
   /// Asserts the index is valid for a given dictionary
    @inlinable
    @inline(__always)
    internal func _assertValid(for dictionary: SortedDictionary) {
      precondition(
        self._root === dictionary._root.root.storage && self._age == dictionary._age,
        "Attempt to use an invalid SortedDictionary index.")
    }
    
    /// Asserts that the index is valid for use with another index
    @inlinable
    @inline(__always)
    internal func _assertValid(with index: Index) {
      precondition(
        self._root != nil && self._root === index._root,
        "Attempt to use an invalid SortedDictionary index.")
    }
  }
}

// MARK: Equatable
extension SortedDictionary.Index: Equatable {
  // TODO: Potentially validate if lhs & rhs aren't pointing to deallocated dictionaries.
  @inlinable
  public static func ==(lhs: SortedDictionary.Index, rhs: SortedDictionary.Index) -> Bool {
    lhs._assertValid(with: rhs)
    return lhs._index == rhs._index
  }
}

// MARK: Comparable
extension SortedDictionary.Index: Comparable {
  @inlinable
  public static func <(lhs: SortedDictionary.Index, rhs: SortedDictionary.Index) -> Bool {
    lhs._assertValid(with: rhs)
    return lhs._index < rhs._index
  }
}
