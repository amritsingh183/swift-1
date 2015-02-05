//===--- RangeTraps.swift -------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
// RUN: rm -rf %t
// RUN: mkdir -p %t
// RUN: %target-build-swift %s -o %t/a.out_Debug
// RUN: %target-build-swift %s -o %t/a.out_Release -O
//
// RUN: %target-run %t/a.out_Debug
// RUN: %target-run %t/a.out_Release

// XFAIL: linux

import StdlibUnittest

var RangeTraps = TestSuite("RangeTraps")

RangeTraps.test("HalfOpen") {
  expectCrashLater()
  1..<0
}

RangeTraps.test("Closed") {
  expectCrashLater()
  1...0
}

RangeTraps.test("OutOfRange") {
  0..<Int.max // This is a Range

  // This works for Intervals, but...
  expectTrue(ClosedInterval(0...Int.max).contains(Int.max))

  // ...no support yet for Ranges containing the maximum representable value
  expectCrashLater()
#if arch(i386)  ||  arch(arm)
  // FIXME <rdar://17670791> Range<Int> bounds checking not enforced in optimized 32-bit
  1...0  // crash some other way
#else
  0...Int.max
#endif
}

runAllTests()

