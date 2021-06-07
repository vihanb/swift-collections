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
///
/// A sorted dictionary is a type of tree, providing efficient read and write operations
/// to the entries it contains. Each entry in the sorted dictionary is identified using a
/// key, which is a comparable type such as a string or number. You can use that key
/// to retrieve the corresponding value.
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
  @inline(__always)
  internal mutating func _invalidateIndices() {
    self._age &+= 1
  }
}

// MARK: Mutations
extension SortedDictionary {
  /// Updates the value stored in the dictionary for the given key, or
  /// adds a new key-value pair if the key does not exist.
  ///
  /// Use this method instead of key-based subscripting when you need to
  /// know whether the new value supplants the value of an existing key. If
  /// the value of an existing key is updated, `updateValue(_:forKey:)` returns
  /// the original value.
  /// 
  /// - Parameters:
  ///   - value: The new value to add to the dictionary.
  ///   - key: The key to associate with value. If key already exists in the
  ///       dictionary, value replaces the existing associated value. If key
  ///       isn’t already a key of the dictionary, the (key, value) pair is added.
  /// - Returns: The value that was replaced, or nil if a new key-value pair was added.
  /// - Complexity: O(`log n`)
  @inlinable
  @discardableResult
  public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
    self._invalidateIndices()
    if let path = self._root.findFirstKey(key) {
      return self._root.setValue(value, at: path)
    } else {
      self._root.insertKey(key, withValue: value)
      return nil
    }
  }

}

// MARK: Subscripts
extension SortedDictionary {
  /// Accesses the value associated with the key for both read and write operations
  ///
  /// This key-based subscript returns the value for the given key if the key is found in
  /// the dictionary, or nil if the key is not found.
  ///
  /// When you assign a value for a key and that key already exists, the dictionary overwrites
  /// the existing value. If the dictionary doesn’t contain the key, the key and value are added
  /// as a new key-value pair.
  ///
  /// - Parameter key: The key to find in the dictionary.
  /// - Returns: The value associated with key if key is in the dictionary; otherwise, nil.
  /// - Complexity: O(`log n`)
  @inlinable
  public subscript(key: Key) -> Value? {
    get {
      let path = self._root.findFirstKey(key)
      return path?.element.value
    }
    
    mutating set {
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
  
  /// Accesses the value with the given key. If the dictionary doesn’t contain the given
  /// key, accesses the provided default value as if the key and default value existed
  /// in the dictionary.
  ///
  /// Use this subscript when you want either the value for a particular key or, when that
  /// key is not present in the dictionary, a default value.
  ///
  /// - Parameters:
  ///   - key: The key the look up in the dictionary.
  ///   - defaultValue: The default value to use if key doesn’t exist in the dictionary.
  /// - Returns: The value associated with key in the dictionary; otherwise, defaultValue.
  /// - Complexity: O(`log n`)
  @inlinable
  public subscript(
    key: Key, default defaultValue: @autoclosure () -> Value
  ) -> Value {
    get {
      return self[key] ?? defaultValue()
    }
    
    mutating set {
      self[key] = newValue
    }
  }
}
