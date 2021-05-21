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
  @usableFromInline
  internal struct _BufferHeader {
    @usableFromInline
    internal var count: Int
    
    @usableFromInline
    init(count: Int) {
      self.count = count
    }
  }
  
  @usableFromInline
  internal class _Buffer<Element>: ManagedBuffer<_BufferHeader, Element> {
    @usableFromInline
    typealias Pointer = ManagedBufferPointer<_BufferHeader, Element>
    
    @usableFromInline
    internal struct Header {
      @usableFromInline
      internal var count: Int
      
      @usableFromInline
      init(count: Int) {
        self.count = count
      }
    }
    
    @inlinable
    @inline(__always)
    internal static func create(capacity: Int, count: Int = 0) -> Pointer {
      let buffer = Self.create(minimumCapacity: capacity) { _ in
        _BufferHeader(count: count)
      }
      return Pointer(unsafeBufferObject: buffer)
    }
    
    @inlinable
    internal static func copy(from oldBuffer: Pointer, capacity: Int) -> Pointer {
      oldBuffer.withUnsafeMutablePointers { header, elements in
        let elementCount = header.pointee.count
        let buffer = Self.create(capacity: capacity, count: elementCount)
      
        buffer.withUnsafeMutablePointerToElements { newElements in
          newElements.initialize(from: elements, count: elementCount)
        }
        
        return buffer
      }
    }
    
    @inlinable
    deinit {
      _ = self.withUnsafeMutablePointers { header, elements in
        elements.deinitialize(count: header.pointee.count)
      }
    }
  }
}
