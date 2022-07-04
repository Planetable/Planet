import Foundation

// weak and unowned object reference in wrapper
// useful in enum, tuple, and other places where `weak` or `unowned` keyword is not allowed

struct Weak<T: AnyObject> {
    unowned var value: T?

    init(_ value: T) {
        self.value = value
    }
}

struct Unowned<T: AnyObject> {
    unowned var value: T

    init(_ value: T) {
        self.value = value
    }
}
