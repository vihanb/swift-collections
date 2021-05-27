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
  internal struct Storage<Element> {
    @usableFromInline
    typealias Buffer = _Node.Buffer<Element>
    
    @usableFromInline
    typealias BufferHeader = _Node.BufferHeader
    
    @usableFromInline
    typealias Pointer = ManagedBufferPointer<BufferHeader, Element>
    
    @usableFromInline
    internal var buffer: Pointer
    
    @inlinable
    @inline(__always)
    internal init(buffer: Pointer) {
      self.buffer = buffer
    }
  }
}

// MARK: Convenience initializers
extension _Node.Storage {
  @inlinable
  @inline(__always)
  internal init(capacity: Int, count: Int = 0) {
    let buffer = Buffer.create(minimumCapacity: capacity) { _ in
      BufferHeader(count: count)
    }
    
    self.init(buffer: Pointer(unsafeBufferObject: buffer))
  }
  
  @inlinable
  internal init(copyingFrom oldStorage: Self, capacity: Int) {
    let elementCount = oldStorage.buffer.header.count
    self.init(capacity: capacity, count: elementCount)
    
    oldStorage.buffer.withUnsafeMutablePointerToElements { elements in
      self.buffer.withUnsafeMutablePointerToElements { newElements in
        newElements.initialize(from: elements, count: elementCount)
      }
    }
  }
}

// MARK: CoW
extension _Node.Storage {
  /// Ensure that this storage refers to a uniquely held buffer by copying
  /// elements if necessary.
  @inlinable
  @inline(__always)
  internal mutating func ensureUnique(capacity: Int) {
    if !self.buffer.isUniqueReference() {
      self = _Node.Storage(copyingFrom: self, capacity: capacity)
    }
  }
}

// MARK: Sequence
extension _Node.Storage: Sequence {
  @usableFromInline
  internal struct Iterator: IteratorProtocol {
    @usableFromInline
    internal let storage: _Node.Storage<Element>
    
    @usableFromInline
    internal var index: Int
    
    @inlinable
    @inline(__always)
    internal init(storage: _Node.Storage<Element>) {
      self.storage = storage
      self.index = 0
    }
    
    @inlinable
    @inline(__always)
    internal mutating func next() -> Element? {
      if self.index >= storage.buffer.header.count {
        return nil
      } else {
        defer { self.index += 1 }
        return storage.buffer.withUnsafeMutablePointerToElements { $0[self.index] }
      }
    }
  }
  
  @inlinable
  @inline(__always)
  __consuming func makeIterator() -> Iterator {
    return Iterator(storage: self)
  }
}

// MARK: CustomDebugStringConvertible
extension _Node.Storage: CustomDebugStringConvertible {
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    Array(self).debugDescription
  }
}
