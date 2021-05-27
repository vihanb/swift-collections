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

/// A collection which maintains key-value pairs in ascending sorted order.
public struct SortedDictionary<Key: Comparable, Value> {
  @usableFromInline
  internal var root: _BTree<Key, Value>
  
  /// Creates an empty dictionary.
  /// 
  /// - Complexity: O(1)
  @inlinable
  @inline(__always)
  public init() {
    self.root = _BTree()
  }
  
  /// Creates a dictionary from a sequence of key-value pairs which must
  /// be unique.
//  @inlinable
//  @inline(__always)
//  public init<S>(
//    uniqueKeysWithValues keysAndValues: S
//  ) where S: Sequence, S.Element == (Key, Value) {
//    self.root = BTree(sequence: keysAndValues)
//  }
}
