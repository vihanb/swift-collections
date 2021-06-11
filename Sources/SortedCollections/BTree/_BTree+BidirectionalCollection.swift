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

extension _BTree: BidirectionalCollection {
  /// The total number of elements contained within the BTree
  /// - Complexity: O(1)
  @inlinable
  @inline(__always)
  internal var count: Int { self.root.storage.header.totalElements }
  
  /// A Boolean value that indicates whether the BTree is empty.
  @inlinable
  @inline(__always)
  internal var isEmpty: Bool { self.count == 0 }
  
  /// An index to an element of the BTree represented as a path.
  @usableFromInline
  internal struct Index: Comparable {
    @usableFromInline
    internal var path: Path?
    
    @inlinable
    @inline(__always)
    internal init(_ path: Path?) {
      self.path = path
    }
    
    @inlinable
    @inline(__always)
    internal static func ==(lhs: Index, rhs: Index) -> Bool {
      return lhs.path?.node === rhs.path?.node
    }
    
    @inlinable
    @inline(__always)
    internal static func <(lhs: Index, rhs: Index) -> Bool {
      switch (lhs.path, rhs.path) {
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
  
  /// Locates the first element and returns a proper path to it, or nil if the BTree is empty.
  /// - Complexity: O(1)
  @inlinable
  internal var startIndex: Index {
    _slowPath(self.isEmpty) ? Index(nil) : Index(self.startPath)
  }
  
  /// Returns a sentinel value for the last element
  /// - Complexity: O(1)
  @inlinable
  internal var endIndex: Index { Index(nil) }
  
  /// Returns the distance between two indices.
  /// - Parameters:
  ///   - start: A valid index of the collection.
  ///   - end: Another valid index of the collection. If end is equal to start, the result is zero.
  /// - Returns: The distance between start and end. The result can be negative only if the collection conforms to the BidirectionalCollection protocol.
  /// - Complexity: O(1)
  @inlinable
  internal func distance(from start: Index, to end: Index) -> Int {
    return (end.path?.index ?? self.count) - (start.path?.index ?? self.count)
  }
  
  /// Replaces the given index with its successor.
  /// - Parameter index: A valid index of the collection. i must be less than endIndex.
  /// - Complexity: O(`log n`) in the worst-case.
  @inlinable
  internal func formIndex(after index: inout Index) {
    guard var path = index.path else {
      preconditionFailure("Attempt to advance out of collection bounds.")
    }
    
    let shouldSeekWithinLeaf = Node(path.node).read({
      $0.isLeaf && _fastPath(path.slot + 1 < $0.numElements)
    })
    
    if shouldSeekWithinLeaf {
      // Continue searching within the same leaf
      path.slot += 1
      path.index += 1
      index.path = path
    } else {
      self.formIndex(&index, offsetBy: 1)
    }
  }
  
  /// Returns the position immediately after the given index.
  /// - Parameter i: A valid index of the collection. i must be less than endIndex.
  /// - Returns: The index value immediately after i.
  /// - Complexity: O(`log n`) in the worst-case.
  @inlinable
  internal func index(after i: Index) -> Index {
    var newIndex = i
    self.formIndex(after: &newIndex)
    return newIndex
  }
  
  /// Replaces the given index with its predecessor.
  /// - Parameter index: A valid index of the collection. i must be greater than startIndex.
  /// - Complexity: O(`log n`) in the worst-case.
  @inlinable
  internal func formIndex(before index: inout Index) {
    assert(index.path != self.startPath, "Attempt to advance out of collection bounds.")
    // TODO: implement more efficient logic to better move through the tree
    self.formIndex(&index, offsetBy: -1)
  }
  
  /// Returns the position immediately before the given index.
  /// - Parameter i: A valid index of the collection. i must be greater than startIndex.
  /// - Returns: The index value immediately before i.
  /// - Complexity: O(`log n`) in the worst-case.
  @inlinable
  internal func index(before i: Index) -> Index {
    var newIndex = i
    self.formIndex(before: &newIndex)
    return newIndex
  }
  
  /// Offsets the given index by the specified distance.
  ///
  /// The value passed as distance must not offset i beyond the bounds of the collection.
  ///
  /// - Parameters:
  ///   - i: A valid index of the collection.
  ///   - distance: The distance to offset `i`.
  /// - Complexity: O(`log n`) in the worst-case.
  @inlinable
  internal func formIndex(_ i: inout Index, offsetBy distance: Int) {
    let newIndex = (i.path?.index ?? self.count) + distance
    assert(0 <= newIndex && newIndex <= self.count, "Attempt to advance out of collection bounds.")
    
    if newIndex == self.count {
      i.path = nil
      return
    }
    
    // TODO: optimization for searching within children
    
    if var path = i.path, path.node.header.children == nil {
      // Check if the target element will be in the same node
      let targetSlot = path.slot + distance
      if 0 <= targetSlot && targetSlot < path.node.header.capacity {
        path.slot = targetSlot
        i.path = path
      }
    }
    
    // Otherwise, re-seek
    i = self.indexToElement(at: newIndex)
  }
  
  /// Returns an index that is the specified distance from the given index.
  /// - Parameters:
  ///   - i: A valid index of the collection.
  ///   - distance: The distance to offset `i`.
  /// - Returns: An index offset by `distance` from the index `i`. If `distance`
  ///     is positive, this is the same value as the result of `distance` calls to
  ///     `index(after:)`. If `distance` is negative, this is the same value as the
  ///     result of `abs(distance)` calls to `index(before:)`.
  @inlinable
  internal func index(_ i: Index, offsetBy distance: Int) -> Index {
    var newIndex = i
    self.formIndex(&newIndex, offsetBy: distance)
    return newIndex
  }
  
  /// Offsets the given index by the specified distance, or so that it equals the given limiting index.
  ///
  /// - Parameters:
  ///   - i: A valid index of the collection.
  ///   - distance: The distance to offset `i`.
  ///   - limit: A valid index of the collection to use as a limit. If `distance > 0`, a limit that is
  ///       less than `i` has no effect. Likewise, if `distance < 0`, a limit that is greater than `i`
  ///       has no effect.
  /// - Returns: `true` if `i` has been offset by exactly `distance` steps without going beyond
  ///     `limit`; otherwise, `false`. When the return value is `false`, the value of `i` is equal
  ///     to `limit`.
  /// - Complexity: O(`log n`) in the worst-case.
  @inlinable
  internal func formIndex(_ i: inout Index, offsetBy distance: Int, limitedBy limit: Index) -> Bool {
    let distanceToLimit = self.distance(from: i, to: limit)
    if distance < 0 ? distanceToLimit > distance : distanceToLimit < distance {
      self.formIndex(&i, offsetBy: distanceToLimit)
      return false
    } else {
      self.formIndex(&i, offsetBy: distance)
      return true
    }
  }
  
  /// Returns an index that is the specified distance from the given index, unless that distance
  /// is beyond a given limiting index.
  ///
  /// - Parameters:
  ///   - i: A valid index of the collection.
  ///   - distance: The distance to offset `i`.
  ///   - limit: A valid index of the collection to use as a limit. If `distance > 0`, a `limit`
  ///       that is less than `i` has no effect. Likewise, if `distance < 0`, a `limit` that is
  ///       greater than `i` has no effect.
  /// - Returns: An index offset by `distance` from the index `i`, unless that index would
  ///     be beyond `limit` in the direction of movement. In that case, the method returns `nil`.
  @inlinable
  internal func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
    let distanceToLimit = self.distance(from: i, to: limit)
    if distance < 0 ? distanceToLimit > distance : distanceToLimit < distance {
      return nil
    } else {
      var newIndex = i
      self.formIndex(&newIndex, offsetBy: distance)
      return newIndex
    }
  }
  
  @inlinable
  internal subscript(index: Index) -> Element {
    assert(index.path != nil, "Attempt to subscript out of range index.")
    return index.path!.element
  }
}
