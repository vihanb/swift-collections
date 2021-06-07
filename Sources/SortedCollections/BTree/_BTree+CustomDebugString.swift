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

extension _BTree: CustomDebugStringConvertible {
  #if DEBUG
  private enum PrintPosition { case start, end, middle }
  private func indentDescription(_ node: _Node<Key, Value>, position: PrintPosition) -> String {
    let label = "(\(node.read { $0.numTotalElements }))"
    
    let spaces = String(repeating: " ", count: label.count)
    
    let lines = describeNode(node).split(separator: "\n")
    return lines.enumerated().map({ index, line in
      var lineToInsert = line
      let middle = (lines.count - 1) / 2
      if index < middle {
        if position == .start {
          return "   " + spaces + lineToInsert
        } else {
          return "┃  " + spaces + lineToInsert
        }
      } else if index > middle {
        if position == .end {
          return "   " + spaces + lineToInsert
        } else {
          return "┃  " + spaces + lineToInsert
        }
      } else {
        switch line[line.startIndex] {
        case "╺": lineToInsert.replaceSubrange(...line.startIndex, with: "━")
        case "┗": lineToInsert.replaceSubrange(...line.startIndex, with: "┻")
        case "┏": lineToInsert.replaceSubrange(...line.startIndex, with: "┳")
        case "┣": lineToInsert.replaceSubrange(...line.startIndex, with: "╋")
        default: break
        }
        
        switch position {
        case .start: return "┏━\(label)━" + lineToInsert
        case .middle: return "┣━\(label)━" + lineToInsert
        case .end: return "┗━\(label)━" + lineToInsert
        }
      }
    }).joined(separator: "\n")
  }
  
  /// A textual representation of this instance, suitable for debugging.
  private func describeNode(_ node: _Node<Key, Value>) -> String {
    node.read { handle in
      var result = ""
      for index in 0..<handle.numElements {
        if !handle.isLeaf {
          let child = handle[childAt: index]
          let childDescription = indentDescription(
            child,
            position: index == 0 ? .start : .middle
          )
          result += childDescription + "\n"
        }
        
        if handle.isLeaf {
          if handle.numElements == 1 {
            result += "╺━ "
          } else if index == handle.numElements - 1 {
            result += "┗━ "
          } else if index == 0 {
            result += "┏━ "
          } else {
            result += "┣━ "
          }
        } else {
          result += "┣━ "
        }
        
        debugPrint(handle[keyAt: index], terminator: ": ", to: &result)
        debugPrint(handle[valueAt: index], terminator: "", to: &result)
        
        if !handle.isLeaf && index == handle.numElements - 1 {
          let childDescription = indentDescription(handle[childAt: index + 1], position: .end)
          result += "\n" + childDescription
        }
        
        result += "\n"
      }
      return result
    }
  }
  
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return "BTree<\(Key.self), \(Value.self)>\n" + indentDescription(self.root, position: .end)
  }
  #else
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return "BTree<\(Key.self), \(Value.self)>(\(self.root))"
  }
  #endif // DEBUG
}
