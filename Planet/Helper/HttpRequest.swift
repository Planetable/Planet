//
//  HttpRequest.swift
//  Planet
//

import Foundation


// Based on swifter framework:
// https://github.com/httpswift/swifter/blob/stable/Xcode/Sources/HttpRequest.swift
// Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//
public class HttpRequest {
    public var path: String = ""
    public var queryParams: [(String, String)] = []
    public var method: String = ""
    public var headers: [String: String] = [:]
    public var body: [UInt8] = []
    public var address: String? = ""
    public var params: [String: String] = [:]

    // MARK: - Constants
    private static let CR = UInt8(13)
    private static let NL = UInt8(10)

    public init() {}

    // MARK: - Public Methods

    /// Checks if a header contains a specific token
    public func hasTokenForHeader(_ headerName: String, token: String) -> Bool {
        guard let headerValue = headers[headerName] else {
            return false
        }
        return headerValue.components(separatedBy: ",")
            .filter({ $0.trimmingCharacters(in: .whitespaces).lowercased() == token })
            .count > 0
    }

    /// Parses URL encoded form data from the request body
    public func parseUrlencodedForm() -> [(String, String)] {
        guard let contentTypeHeader = headers["content-type"] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let contentType = contentTypeHeaderTokens.first, contentType == "application/x-www-form-urlencoded" else {
            return []
        }
        guard let utf8String = String(bytes: body, encoding: .utf8) else {
            // Consider to throw an exception here (examine the encoding from headers).
            return []
        }
        return utf8String.components(separatedBy: "&").map { param -> (String, String) in
            let tokens = param.components(separatedBy: "=")
            if let name = tokens.first?.removingPercentEncoding, let value = tokens.last?.removingPercentEncoding, tokens.count == 2 {
                return (name.replacingOccurrences(of: "+", with: " "),
                        value.replacingOccurrences(of: "+", with: " "))
            }
            return ("", "")
        }
    }

    /// Parses multipart form data from the request body
    public func parseMultiPartFormData() -> [MultiPart] {
        guard let contentTypeHeader = headers["content-type"] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let contentType = contentTypeHeaderTokens.first, contentType == "multipart/form-data" else {
            return []
        }
        var boundary: String?
        contentTypeHeaderTokens.forEach({
            let tokens = $0.components(separatedBy: "=")
            if let key = tokens.first, key == "boundary" && tokens.count == 2 {
                boundary = tokens.last
            }
        })
        if let boundary = boundary, boundary.utf8.count > 0 {
            return parseMultiPartFormData(body, boundary: "--\(boundary)")
        }
        return []
    }

    // MARK: - MultiPart Structure

    public struct MultiPart {
        public let headers: [String: String]
        public let body: [UInt8]

        public var name: String? {
            return parseParameterValue(from: "content-disposition", parameter: "name")
        }

        public var fileName: String? {
            return parseParameterValue(from: "content-disposition", parameter: "filename")
        }

        // Improved parsing of header parameter values
        private func parseParameterValue(from headerName: String, parameter: String) -> String? {
            guard let headerValue = headers[headerName] else { return nil }

            // Parse the header value correctly handling quoted values with special characters
            let segments = headerValue.components(separatedBy: ";")
            for segment in segments {
                let trimmed = segment.trimmingCharacters(in: .whitespaces)

                // Check for parameter=value format
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let paramName = trimmed[..<equalsIndex].trimmingCharacters(in: .whitespaces)
                    let paramValue = trimmed[trimmed.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)

                    if paramName == parameter {
                        // Found our parameter
                        var result = paramValue
                        if result.hasPrefix("\"") && result.hasSuffix("\"") {
                            result = String(result.dropFirst().dropLast())
                        }
                        debugPrint("unquoted: \(result)")
                        return result
                    }
                }
            }

            return nil
        }
    }

    // MARK: - Private Methods

    private func parseMultiPartFormData(_ data: [UInt8], boundary: String) -> [MultiPart] {
        var generator = data.makeIterator()
        var result = [MultiPart]()
        while let part = nextMultiPart(&generator, boundary: boundary, isFirst: result.isEmpty) {
            result.append(part)
        }
        return result
    }

    private func nextMultiPart(_ generator: inout IndexingIterator<[UInt8]>, boundary: String, isFirst: Bool) -> MultiPart? {
        if isFirst {
            guard nextUTF8MultiPartLine(&generator) == boundary else {
                return nil
            }
        } else {
            let /* ignore */ _ = nextUTF8MultiPartLine(&generator)
        }

        var headers = [String: String]()
        while let line = nextUTF8MultiPartLine(&generator), !line.isEmpty {
            // Find the first colon to separate header name from value
            guard let colonIndex = line.firstIndex(of: ":") else { continue }

            // Everything before the first colon is the header name
            let name = String(line[..<colonIndex]).lowercased().trimmingCharacters(in: .whitespaces)

            // Everything after the first colon is the value (this preserves any other colons in the value)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            debugPrint("Header parsed: \(name) = \(value)")
            headers[name] = value
        }

        guard let body = nextMultiPartBody(&generator, boundary: boundary) else {
            return nil
        }

        return MultiPart(headers: headers, body: body)
    }

    private func nextUTF8MultiPartLine(_ generator: inout IndexingIterator<[UInt8]>) -> String? {
        var temp = [UInt8]()
        while let value = generator.next() {
            if value > HttpRequest.CR {
                temp.append(value)
            }
            if value == HttpRequest.NL {
                break
            }
        }
        return String(bytes: temp, encoding: String.Encoding.utf8)
    }

    private func nextMultiPartBody(_ generator: inout IndexingIterator<[UInt8]>, boundary: String) -> [UInt8]? {
        var body = [UInt8]()
        let boundaryArray = [UInt8](boundary.utf8)
        var matchOffset = 0
        while let x = generator.next() {
            matchOffset = (x == boundaryArray[matchOffset] ? matchOffset + 1 : 0)
            body.append(x)
            if matchOffset == boundaryArray.count {
                #if swift(>=4.2)
                body.removeSubrange(body.count-matchOffset ..< body.count)
                #else
                body.removeSubrange(CountableRange<Int>(body.count-matchOffset ..< body.count))
                #endif
                if body.last == HttpRequest.NL {
                    body.removeLast()
                    if body.last == HttpRequest.CR {
                        body.removeLast()
                    }
                }
                return body
            }
        }
        return nil
    }
}
