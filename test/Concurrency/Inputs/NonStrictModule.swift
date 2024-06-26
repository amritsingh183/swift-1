public struct NonStrictStruct { }

open class NonStrictClass {
  public init() {}
  open func send(_ body: @Sendable () -> Void) {}
  open func dontSend(_ body: () -> Void) {}
}

public protocol NonStrictProtocol {
  func send(_ body: @Sendable () -> Void)
  func dontSend(_ body: () -> Void)
}
