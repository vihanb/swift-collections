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

extension _BTree: Collection {
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
  
  /// Forms the index after
  /// - Parameter index: <#index description#>
  @inlinable
  internal func formIndex(after index: inout Index) {
    guard var path = index.path else {
      preconditionFailure("Attempt to advance out of collection bounds.")
    }
    
    Node(path.node).read { handle in
      if handle.isLeaf {
        if _fastPath(path.slot + 1 < handle.numElements) {
          // Continue searching within the same leaf
          path.slot += 1
        } else {
          // Re-traverse to find lowest where offset[parentDepth + 1] is a valid index
          var lastShiftableDepth = -1
          var lastShiftableSlot = -1
          
          // Making these unowned shouldn't be an issue, as it removes (?)
          // some unneeded swift_retains. If some bug arises with this section
          // of code, this may be a culprit though.
          unowned var lastShiftableNode: Node.Storage? = nil
          unowned var currentAncestor = self.root.storage
          
          for depth in 0..<path.offsets.count {
            let numElems = Node(currentAncestor).read { $0.numElements }
            let offset = path.offsets[depth]
            if offset < numElems {
              lastShiftableDepth = depth
              lastShiftableNode = currentAncestor
              lastShiftableSlot = offset
            }
            currentAncestor = Node(currentAncestor).read { $0[childAt: offset].storage }
          }
          
          if let lastShiftableNode = lastShiftableNode {
            path.offsets.removeLast(path.offsets.count - lastShiftableDepth)
            
            path.node = lastShiftableNode
            path.slot = lastShiftableSlot
            
            path.validatePath()
          } else {
            index.path = nil
            return
          }
        }
      } else {
        // Descend to leaf of child[slot + 1]
        var child = handle[childAt: path.slot + 1]
        path.offsets.append(path.slot + 1)
        
        if !child.read({ $0.isLeaf }) {
          while true {
            child.read { handle in
              child = handle[childAt: 0]
            }
            
            if child.read({ $0.isLeaf }) {
              break
            } else {
              path.offsets.append(0)
            }
          }
        }
        
        path.node = child.storage
        path.slot = 0
      }
      
      index.path = path
    }
  }
  
  @inlinable
  public func index(after i: Index) -> Index {
    var newIndex = i
    self.formIndex(after: &newIndex)
    return newIndex
  }
  
  @inlinable
  internal subscript(index: Index) -> Element {
    return index.path!.element
  }
}
