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

#ifndef RUST_BENCHMARKS_H
#define RUST_BENCHMARKS_H

#include <stdint.h>

typedef void* RustMap;

RustMap create_map(intptr_t count, const intptr_t* keys);

void destroy_map(RustMap map);

void map_lookups(RustMap map, intptr_t count, const intptr_t* keys);


#endif /* RUST_BENCHMARKS_H */
