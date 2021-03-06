// RUN: %target-run-simple-swift
// TODO(TF-1254): Support and test forward-mode differentiation.
// TODO(TF-1254): %target-run-simple-swift(-Xfrontend -enable-experimental-forward-mode-differentiation)
// REQUIRES: executable_test

import StdlibUnittest
import DifferentiationUnittest

var PropertyWrapperTests = TestSuite("PropertyWrapperDifferentiation")

@propertyWrapper
struct SimpleWrapper<Value> {
  var wrappedValue: Value // stored property
}

@propertyWrapper
struct Wrapper<Value> {
  private var value: Value
  var wrappedValue: Value { // computed property
    get { value }
    set { value = newValue }
  }

  init(wrappedValue: Value) {
    self.value = wrappedValue
  }
}

struct Struct: Differentiable {
  @Wrapper @SimpleWrapper var x: Tracked<Float> = 10
  @SimpleWrapper @Wrapper var y: Tracked<Float> = 20
  var z: Tracked<Float> = 30
}

PropertyWrapperTests.test("SimpleStruct") {
  func getter(_ s: Struct) -> Tracked<Float> {
    return s.x
  }
  expectEqual(.init(x: 1, y: 0, z: 0), gradient(at: Struct(), in: getter))

  func setter(_ s: Struct, _ x: Tracked<Float>) -> Tracked<Float> {
    var s = s
    s.x = s.x * x * s.z
    return s.x
  }
  expectEqual((.init(x: 60, y: 0, z: 20), 300),
              gradient(at: Struct(), 2, in: setter))

  // TODO(SR-12640): Support `modify` accessors.
  /*
  func modify(_ s: Struct, _ x: Tracked<Float>) -> Tracked<Float> {
    var s = s
    s.x *= x * s.z
    return s.x
  }
  expectEqual((.init(x: 60, y: 0, z: 20), 300),
              gradient(at: Struct(), 2, in: modify))
  */
}

struct GenericStruct<T> {
  @Wrapper var x: Tracked<Float> = 10
  @Wrapper @Wrapper @Wrapper var y: T
  var z: Tracked<Float> = 30
}
extension GenericStruct: Differentiable where T: Differentiable {}

PropertyWrapperTests.test("GenericStruct") {
  func getter<T>(_ s: GenericStruct<T>) -> T {
    return s.y
  }
  expectEqual(.init(x: 0, y: 1, z: 0),
              gradient(at: GenericStruct<Tracked<Float>>(y: 20), in: getter))

  func getter2<T>(_ s: GenericStruct<T>) -> Tracked<Float> {
    return s.x * s.z
  }
  expectEqual(.init(x: 30, y: 0, z: 10),
              gradient(at: GenericStruct<Tracked<Float>>(y: 20), in: getter2))

  func setter<T>(_ s: GenericStruct<T>, _ x: Tracked<Float>) -> Tracked<Float> {
    var s = s
    s.x = s.x * x * s.z
    return s.x
  }
  expectEqual((.init(x: 60, y: 0, z: 20), 300),
              gradient(at: GenericStruct<Tracked<Float>>(y: 20), 2, in: setter))

  // TODO(SR-12640): Support `modify` accessors.
  /*
  func modify<T>(_ s: GenericStruct<T>, _ x: Tracked<Float>) -> Tracked<Float> {
    var s = s
    s.x *= x * s.z
    return s.x
  }
  expectEqual((.init(x: 60, y: 0, z: 20), 300),
              gradient(at: GenericStruct<Tracked<Float>>(y: 1), 2, in: modify))
  */
}

// FIXME(TF-1149): Cannot differentiate active value with loadable type but
// address-only tangent type. Triggered by marking properties with
// `@differentiable`, which triggers derivative vtable thunk entries.
/*
class Class: Differentiable {
  @differentiable
  @Wrapper @Wrapper var x: Tracked<Float> = 10

  @differentiable
  @Wrapper var y: Tracked<Float> = 20

  @differentiable
  var z: Tracked<Float> = 30
}

PropertyWrapperTests.test("SimpleClass") {
  func getter(_ c: Class) -> Tracked<Float> {
    return c.x
  }
  expectEqual(.init(x: 1, y: 0, z: 0), gradient(at: Class(), in: getter))

  func setter(_ c: Class, _ x: Tracked<Float>) -> Tracked<Float> {
    var c = c
    c.x = c.x * x * c.z
    return c.x
  }
  expectEqual((.init(x: 60, y: 0, z: 20), 300),
              gradient(at: Class(), 2, in: setter))

  // TODO(SR-12640): Support `modify` accessors.
  /*
  func modify(_ c: Class, _ x: Tracked<Float>) -> Tracked<Float> {
    var c = c
    c.x *= x * c.z
    return c.x
  }
  expectEqual((.init(x: 60, y: 0, z: 20), 300),
              gradient(at: Class(), 2, in: modify))
  */
}
*/

// From: https://github.com/apple/swift-evolution/blob/master/proposals/0258-property-wrappers.md#proposed-solution
@propertyWrapper
enum Lazy<Value> {
  case uninitialized(() -> Value)
  case initialized(Value)

  init(wrappedValue: @autoclosure @escaping () -> Value) {
    self = .uninitialized(wrappedValue)
  }

  var wrappedValue: Value {
    get {
      switch self {
      case .uninitialized(let initializer):
        let value = initializer()
        return value
      case .initialized(let value):
        return value
      }
    }
    set {
      self = .initialized(newValue)
    }
  }
}

// From: https://github.com/apple/swift-evolution/blob/master/proposals/0258-property-wrappers.md#clamping-a-value-within-bounds
@propertyWrapper
struct Clamping<V: Comparable> {
  var value: V
  let min: V
  let max: V

  init(wrappedValue: V, min: V, max: V) {
    value = wrappedValue
    self.min = min
    self.max = max
    assert(value >= min && value <= max)
  }

  var wrappedValue: V {
    get { return value }
    set {
      if newValue < min {
        value = min
      } else if newValue > max {
        value = max
      } else {
        value = newValue
      }
    }
  }
}

struct RealPropertyWrappers: Differentiable {
  @Lazy var x: Float = 3

  @Clamping(min: -10, max: 10)
  var y: Float = 4
}

PropertyWrapperTests.test("RealPropertyWrappers") {
  @differentiable
  func multiply(_ s: RealPropertyWrappers) -> Float {
    return s.x * s.y
  }
  expectEqual(.init(x: 4, y: 3),
              gradient(at: RealPropertyWrappers(x: 3, y: 4), in: multiply))
}

runAllTests()
