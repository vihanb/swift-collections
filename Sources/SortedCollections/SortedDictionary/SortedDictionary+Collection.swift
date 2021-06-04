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

extension SortedDictionary: Collection {
  // TODO: needs to be weak
  public var startIndex: Index { Index(_path: _Tree.Path(firstElementOf: self._root)) }
  public var endIndex: Index { Index(_path: nil) }
  
  public func index(after i: Index) -> Index {
    return Index(_path: i._path?.advanced())
  }
  
  public subscript(position: Index) -> Element {
    precondition(position._path != nil,
                 "Attempting to access sorted dictionary element with invalid index.")
    return position._path!.element
  }
}
