//
//  KeychainHelper.swift
//  Planet
//
//  Created by Kai on 3/8/23.
//

import Foundation
import os


class KeychainHelper: NSObject {
    static let shared = KeychainHelper()
    
    func saveValue(_ value: String, forKey key: String) throws {
        guard value.count > 0, let data = value.data(using: .utf8) else {
            throw PlanetError.KeychainSaveKeyError
        }
        let saveQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]
        SecItemDelete(saveQuery as CFDictionary)
        let status = SecItemAdd(saveQuery as CFDictionary, nil)
        if status != errSecSuccess {
            throw PlanetError.KeychainSaveKeyError
        }
    }
    
    func loadValue(forKey key: String) throws -> String {
        let loadQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(loadQuery as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw PlanetError.KeychainLoadKeyError
        }
        guard let data = item as? Data else {
            throw PlanetError.KeychainLoadKeyError
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw PlanetError.KeychainLoadKeyError
        }
        return value
    }
    
    func deleteValue(forKey key: String) throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]
        let status = SecItemDelete(deleteQuery as CFDictionary)
        if status != errSecSuccess {
            throw PlanetError.KeychainDeleteKeyError
        }
    }
}
