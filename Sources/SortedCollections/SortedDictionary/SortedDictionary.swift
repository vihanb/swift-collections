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
public class SortedDictionary<Key: Comparable, Value> {
  
  /// Creates an empty dictionary.
  /// 
  /// - Complexity: O(1)
  @inlinable
  @inline(__always)
  public init() {
    
  }
  
  /// Creates a dictionary from a sequence of key-value pairs which must
  /// be unique.
  @inlinable
  public init<S: Sequence>(
    uniqueKeysWithValues keysAndValues: S
  ) where S.Element == (Key, Value) {
    
  }
}
