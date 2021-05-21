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

extension Node {
  #if COLLECTIONS_INTERNAL_CHECKS
  @inline(never)
  public func _checkInvariants() {
    precondition(capacity > 0, "Capacity must be strictly positive.")
    precondition(count <= capacity, "Overfilled node.")
    precondition(keys.count == count, "Key count mismatch.")
    precondition(values.count == count, "Value count mismatch.")
    precondition(children.count <= count + 1 || children.count === 1, "Invalid children count for node.")
    
    // Validate the node is sorted
    // TODO: is this too heavy to put in an invariant check?
    for i in 0..<(count - 1) {
      precondition(keys[i] <= keys[i + 1], "Node is out-of-order.")
    }
  }
  #else
  @inline(__always) @inlinable
  public func _checkInvariants() {}
  #endif // COLLECTIONS_INTERNAL_CHECKS
}
