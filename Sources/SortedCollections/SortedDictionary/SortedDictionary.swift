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
  /// An element of the sorted dictionary. A key-value tuple.
  public typealias Element = (key: Key, value: Value)
  
  @usableFromInline
  internal typealias _Tree = _BTree<Key, Value>
  
  @usableFromInline
  internal var _root: _Tree
  
  /// A metric to uniquely identify a sorted dictionary's state. It is not
  /// impossible for two dictionaries to have the same age by pure
  /// coincidence.
  @usableFromInline
  internal var _age: Int32
  
  /// Creates an empty dictionary.
  /// 
  /// - Complexity: O(1)
  @inlinable
  @inline(__always)
  public init() {
    self._root = _Tree()
    self._age = Int32(truncatingIfNeeded: ObjectIdentifier(self._root.root.storage).hashValue)
  }
  
  /// Creates a dictionary rooted at a given BTree.
  @inlinable
  internal init(_rootedAt tree: _Tree) {
    self._root = tree
    self._age = Int32(truncatingIfNeeded: ObjectIdentifier(self._root.root.storage).hashValue)
  }
  
  /// Creates a dictionary from a sequence of key-value pairs which must
  /// be unique.
  /// - Complexity: O(`n log n`)
  @inlinable
  @inline(__always)
  public init<S>(
    uniqueKeysWithValues keysAndValues: S
  ) where S: Sequence, S.Element == Element {
    // TODO: optimize to O(N)
    self.init()
    
    for (key, value) in keysAndValues {
      self._root.insertKey(key, withValue: value)
    }
  }
  
  /// Invalidates the issued indices of the dictionary. Ensure this is
  /// called for operations which mutate the SortedDictionary.
  @inlinable
  internal mutating func _invalidateIndices() {
    self._age &+= 1
  }
}

// MARK: Subscripts
extension SortedDictionary {
  /// Accesses the value associated with the key for both read and write operations
  /// - Complexity: O(`log n`)
  @inlinable
  public subscript(key: Key) -> Value? {
    get {
      let path = self._root.findFirstKey(key)
      return path?.element.value
    }
    
    set {
      self._invalidateIndices()
      
      let path = self._root.findFirstKey(key)
      switch (newValue, path) {
      case let (newValue?, path?): // Assignment
        self._root.setValue(newValue, at: path)
      case let (newValue?, nil): // Insertino
        self._root.insertKey(key, withValue: newValue)
      case let (nil, path?): // Removal
        break // TODO: implement remove
      case (nil, nil): // Noop
        break 
      }
    }
  }
  
  /// Accesses the value associated with the key for both read and write operations.
  /// If the key does not exist in the dictionary, this returns a default value.
  @inlinable
  public subscript(
    key: Key, default defaultValue: @autoclosure () -> Value
  ) -> Value {
    get {
      return self[key] ?? defaultValue()
    }
    
    set {
      self[key] = newValue
    }
  }
}
