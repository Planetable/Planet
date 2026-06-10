import Foundation

enum PNJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }()

    static let compactEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static let decoder = JSONDecoder()

    static func data<T: Encodable>(from value: T, pretty: Bool = true) throws -> Data {
        try (pretty ? encoder : compactEncoder).encode(value)
    }

    static func string<T: Encodable>(from value: T, pretty: Bool = true) throws -> String {
        let data = try data(from: value, pretty: pretty)
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        try decoder.decode(type, from: Data(contentsOf: url))
    }

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    static func readObject(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard
            let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            throw PNError.diskError("Expected JSON object at \(url.path).")
        }
        return object
    }

    static func writeObject(_ object: [String: Any], to url: URL) throws {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw PNError.diskError("Cannot write invalid JSON object to \(url.path).")
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }

    static func dateNumber(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
    }
}

enum PNDateParser {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String) throws -> Date {
        if let date = isoFormatter.date(from: value) ?? fallbackISOFormatter.date(from: value) {
            return date
        }
        throw PNError.invalidOption("Invalid ISO 8601 date: \(value)")
    }

    static func format(_ date: Date?) -> String {
        guard let date else { return "" }
        return fallbackISOFormatter.string(from: date)
    }
}
