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

extension Node: CustomDebugStringConvertible {
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    self.read { handle in
      var result = "Node<\(Key.self), \(Value.self)>(["
      var first = true
      for index in 0..<handle.numElements {
        if first {
          first = false
        } else {
          result += ", "
        }
        result += "("
        debugPrint(handle.keys[index], terminator: ", ", to: &result)
        debugPrint(handle.values[index], terminator: ")", to: &result)
      }
      result += "])"
      return result
    }
  }
}
