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
      return Index(_path: path)
    } else {
      return nil
    }
  }
  
  /// The position of an element within a sorted dictionary
  public struct Index {
    // TODO: invalidation of sorts
    internal let _path: _Tree.Path?
    
    internal init(_path: _Tree.Path?) {
      self._path = _path
    }
  }
}

// MARK: Equatable
extension SortedDictionary.Index: Equatable {
  public static func ==(lhs: SortedDictionary.Index, rhs: SortedDictionary.Index) -> Bool {
    // TODO: ensure referring to the same collection
    return lhs._path == rhs._path
  }
}

// MARK: Comparable
extension SortedDictionary.Index: Comparable {
  public static func <(lhs: SortedDictionary.Index, rhs: SortedDictionary.Index) -> Bool {
    // TODO: if branch prediction does not do well here, potentially change to
    // branch with explicit _fastPath
    switch (lhs._path, rhs._path) {
    case let (lhsPath?, rhsPath?):
      return lhsPath < rhsPath
    case (_?, nil):
      return true
    case (nil, _?):
      return false
    case (nil, nil):
      return false
    }
  }
}
