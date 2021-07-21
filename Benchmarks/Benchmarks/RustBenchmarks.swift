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

import CollectionsBenchmark
import RustBenchmarks

internal class RustMap {
  var ptr: UnsafeMutableRawPointer?

  init(_ input: [Int]) {
    self.ptr = input.withUnsafeBufferPointer { buffer in
      create_map(buffer.count, buffer.baseAddress)
    }
  }

  deinit {
    destroy()
  }

  func destroy() {
    if let ptr = ptr {
      destroy_map(ptr)
    }
    ptr = nil
  }
}

extension Benchmark {
  public mutating func addRustBenchmarks() {
    self.add(
      title: "std::collections::BTreeMap<i64, i64> successful find",
      input: ([Int], [Int]).self
    ) { input, lookups in
      let map = RustMap(input)
      return { timer in
        lookups.withUnsafeBufferPointer { buffer in
          map_lookups(map.ptr, buffer.count, buffer.baseAddress)
        }
      }
    }
  }
}
