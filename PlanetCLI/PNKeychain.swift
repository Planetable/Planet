import Foundation
import Security

enum PNKeychain {
    static func apiPasscode() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: PNPreferences.settingsAPIPasscode,
            kSecAttrService as String: PNPreferences.bundleIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw PNError.apiUnavailable("Planet API authentication is enabled, but pn could not read the API passcode from Keychain.")
        }
        return value
    }
}
