import Foundation

enum PNError: Error, CustomStringConvertible {
    case usage(String)
    case invalidOption(String)
    case notFound(String)
    case ambiguous(String)
    case apiUnavailable(String)
    case apiError(Int, String)
    case diskError(String)
    case runtime(String)

    var description: String {
        switch self {
        case .usage(let message),
             .invalidOption(let message),
             .notFound(let message),
             .ambiguous(let message),
             .apiUnavailable(let message),
             .diskError(let message),
             .runtime(let message):
            return message
        case .apiError(let status, let message):
            if message.isEmpty {
                return "API request failed with HTTP \(status)."
            }
            return "API request failed with HTTP \(status): \(message)"
        }
    }
}

extension String {
    var pnTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var pnNilIfEmpty: String? {
        let value = pnTrimmed
        return value.isEmpty ? nil : value
    }

    func pnCaseInsensitiveEquals(_ other: String) -> Bool {
        compare(other, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    func pnCaseInsensitiveContains(_ other: String) -> Bool {
        range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
