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

extension _Node {
  @usableFromInline
  internal struct BufferHeader {
    @usableFromInline
    internal var count: Int
    
    @usableFromInline
    init(count: Int) {
      self.count = count
    }
  }
  
  @usableFromInline
  internal class Buffer<Element>: ManagedBuffer<BufferHeader, Element> {
    @inlinable
    deinit {
      _ = self.withUnsafeMutablePointers { header, elements in
        elements.deinitialize(count: header.pointee.count)
      }
    }
  }
}
