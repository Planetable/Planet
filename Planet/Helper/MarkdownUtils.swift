import Foundation
import Stencil

struct StencilExtension {
    static func get() -> Extension {
        let ext = Extension()
        ext.registerFilter("formatDate") { value in
            if let value = value,
               let date = value as? Date {
                let format = DateFormatter()
                format.dateStyle = .medium
                format.timeStyle = .medium
                return format.string(from: date)
            }
            return "Test"
        }
        return ext
    }
}
