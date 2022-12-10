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
        ext.registerFilter("md2html") { value in
            if let value = value,
               let md = value as? String {
                if let html = CMarkRenderer.renderMarkdownHTML(markdown: md) {
                    return html
                }
            }
            return value
        }
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
        ext.registerFilter("formatDateC") { value in
            if let value = value,
               let date = value as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                let formattedDate = formatter.string(from: date)
                return formattedDate
            }
            return value
        }
        ext.registerFilter("ymd") { value in
            if let value = value,
               let date = value as? Date {
                let format = DateFormatter()
                format.dateStyle = .medium
                format.timeStyle = .none
                return format.string(from: date)
            }
            return value
        }
        ext.registerFilter("hhmmss") { value in
            if let value = value,
               let seconds = value as? Int {
                let hours = seconds / 3600
                let minutes = (seconds % 3600) / 60
                let seconds = seconds % 60
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
               }
            return "00:00:00"
        }
        ext.registerFilter("rfc822") { value in
            if let value = value,
               let date = value as? Date {
                let RFC822DateFormatter = DateFormatter()
                RFC822DateFormatter.locale = Locale(identifier: "en_US_POSIX")
                RFC822DateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                return RFC822DateFormatter.string(from: date)
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
    static var _parser: UnsafeMutablePointer<cmark_parser>? = nil
    static var parser: UnsafeMutablePointer<cmark_parser>? {
        if let singleton = _parser {
            return singleton
        }

        cmark_gfm_core_extensions_ensure_registered()

        guard let newSingleton = cmark_parser_new(CMARK_OPT_FOOTNOTES) else {
            return nil
        }

        if let ext = cmark_find_syntax_extension("table") {
            cmark_parser_attach_syntax_extension(newSingleton, ext)
        }
        if let ext = cmark_find_syntax_extension("autolink") {
            cmark_parser_attach_syntax_extension(newSingleton, ext)
        }
        if let ext = cmark_find_syntax_extension("strikethrough") {
            cmark_parser_attach_syntax_extension(newSingleton, ext)
        }
        if let ext = cmark_find_syntax_extension("tasklist") {
            cmark_parser_attach_syntax_extension(newSingleton, ext)
        }

        _parser = newSingleton
        return newSingleton
    }

    // Reference: https://github.com/tw93/MiaoYan/blob/master/Mac/Business/Markdown.swift
    static func renderMarkdownHTML(markdown: String) -> String? {
        guard let parser = Self.parser else {
            return nil
        }
        cmark_parser_feed(parser, markdown, markdown.utf8.count)
        guard let node = cmark_parser_finish(parser) else { return nil }

        // use GitHub flavored rules: render line break in <p> as <br>
        // Reference: https://github.com/theacodes/cmarkgfm/blob/master/README.rst#advanced-usage
        return String(cString: cmark_render_html(node, CMARK_OPT_UNSAFE | CMARK_OPT_HARDBREAKS, nil))
    }
}
