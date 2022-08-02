import Foundation
import Stencil
import libcmark_gfm
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


struct CMarkRenderer {
    // Reference: https://github.com/tw93/MiaoYan/blob/master/Mac/Business/Markdown.swift
    static func renderMarkdownHTML(markdown: String) -> String? {
        cmark_gfm_core_extensions_ensure_registered()

        guard let parser = cmark_parser_new(CMARK_OPT_FOOTNOTES) else { return nil }
        defer { cmark_parser_free(parser) }

        if let ext = cmark_find_syntax_extension("table") {
            cmark_parser_attach_syntax_extension(parser, ext)
        }

        if let ext = cmark_find_syntax_extension("autolink") {
            cmark_parser_attach_syntax_extension(parser, ext)
        }

        if let ext = cmark_find_syntax_extension("strikethrough") {
            cmark_parser_attach_syntax_extension(parser, ext)
        }

        if let ext = cmark_find_syntax_extension("tasklist") {
            cmark_parser_attach_syntax_extension(parser, ext)
        }

        cmark_parser_feed(parser, markdown, markdown.utf8.count)
        guard let node = cmark_parser_finish(parser) else { return nil }

        // var res = String(cString: cmark_render_html(node, CMARK_OPT_UNSAFE | CMARK_OPT_HARDBREAKS, nil))
        // if UserDefaultsManagement.editorLineBreak == "Github" {
        //     res = String(cString: cmark_render_html(node, CMARK_OPT_UNSAFE | CMARK_OPT_NOBREAKS, nil))
        // }
        // return res
        return String(cString: cmark_render_html(node, CMARK_OPT_UNSAFE | CMARK_OPT_NOBREAKS, nil))
    }
}

// struct InkModifier {
//     static let draftPreviewImages: Modifier = {
//         Modifier(target: .images) { html, _ in
//             let parts = html.split(separator: "\"", maxSplits: 2, omittingEmptySubsequences: false)
//             if parts.count == 3,
//                parts[0] == "<img src=" {
//                 let imageURL = parts[1]
//                 let imageURLWithTimestamp = "\(imageURL)?t=\(Int(Date().timeIntervalSince1970))"
//                 return "\(parts[0])\"\(imageURLWithTimestamp)\"\(parts[2])"
//             }
//             // probably not an <img> element with proper URL, return HTML as is
//             return html
//         }
//     }()
// }
