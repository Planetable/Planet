import Foundation
import Stencil
import Ink
import HTMLEntities

struct StencilExtension {
    static let common: Extension = {
        let ext = Extension()
        ext.registerFilter("formatDate") { value in
            if let value = value,
               let date = value as? Date {
                let format = DateFormatter()
                format.dateStyle = .medium
                format.timeStyle = .medium
                return format.string(from: date)
            }
            return value
        }
        ext.registerFilter("escapeString") { value in
            if let value = value,
               let str = value as? String,
               let jsonData = try? JSONEncoder.shared.encode(str),
               let jsonEscapedString = String(data: jsonData, encoding: .utf8) {
                return jsonEscapedString
            }
            return value
        }
        ext.registerFilter("escapeHTML") { value in
            if let value = value,
               let str = value as? String {
                return str.htmlEscape()
            }
            return value
        }
        return ext
    }()
}

struct InkModifier {
    static let draftPreviewImages: Modifier = {
        Modifier(target: .images) { html, _ in
            let parts = html.split(separator: "\"", maxSplits: 2, omittingEmptySubsequences: false)
            if parts.count == 3,
               parts[0] == "<img src=" {
                let imageURL = parts[1]
                let imageURLWithTimestamp = "\(imageURL)?t=\(Int(Date().timeIntervalSince1970))"
                return "\(parts[0])\"\(imageURLWithTimestamp)\"\(parts[2])"
            }
            // probably not an <img> element with proper URL, return HTML as is
            return html
        }
    }()
}
