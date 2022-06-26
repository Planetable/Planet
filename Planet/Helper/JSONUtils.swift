import Foundation

struct SerializationError: Error {
}

extension Decoder {
    func getContext<T>(key: String) throws -> T {
        let infoKey = CodingUserInfoKey(rawValue: key)!
        if let context = userInfo[infoKey] as? T {
            return context
        }
        throw SerializationError()
    }
}

extension JSONDecoder {
    static let shared = JSONDecoder()

    func setContext<T>(_ context: T, key: String) {
        let infoKey = CodingUserInfoKey(rawValue: key)!
        userInfo[infoKey] = context
    }
}

extension JSONEncoder {
    static let shared = JSONEncoder()
}
