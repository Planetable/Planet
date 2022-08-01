import Foundation
import Stencil
import Ink
import HTMLEntities

struct StencilExtension {
    static let escapeJSTable: [Character: String] = {
        var table: [Character: String] = [
            "\\": "\\u005C",
            "'": "\\u0027",
            "\"": "\\u0022",
            ">": "\\u003E",
            "<": "\\u003C",
            "&": "\\u0026",
            "=": "\\u003D",
            "-": "\\u002D",
            ";": "\\u003B",
            "\u{2028}": "\\u2028",
            "\u{2029}": "\\u2029",
        ]
        for i in 0..<32 {
            let char = Character(Unicode.Scalar(i)!)
            let escapedString = String(format: "\\u%04X", i)
            table[char] = escapedString
        }
        return table
    }()

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
        ext.registerFilter("escapejs") { value in
            if let value = value,
               let str = value as? String {
                var escapedString = ""
                for char in str {
                    if let escapedChar = escapeJSTable[char] {
                        escapedString.append(escapedChar)
                    } else {
                        escapedString.append(char)
                    }
                }
                return escapedString
            }
            return ""
        }
        ext.registerFilter("escape") { value in
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
