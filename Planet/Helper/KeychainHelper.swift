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
    
    func saveData(_ data: Data, forKey key: String, withICloudSync sync: Bool = false) throws {
        let saveQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ]
        Task(priority: .utility) {
            SecItemDelete(saveQuery as CFDictionary)
            let status = SecItemAdd(saveQuery as CFDictionary, nil)
            if status != errSecSuccess {
                throw PlanetError.KeyManagerSavingKeyError
            }
        }
    }

    func loadData(forKey key: String, withICloudSync sync: Bool = false) throws -> Data {
        let loadQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(loadQuery as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        guard let data = item as? Data else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        return data
    }
    
    func saveValue(_ value: String, forKey key: String, withICloudSync sync: Bool = false) throws {
        guard value.count > 0, let data = value.data(using: .utf8) else {
            throw PlanetError.KeyManagerSavingKeyError
        }
        let saveQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ]
        Task(priority: .utility) {
            SecItemDelete(saveQuery as CFDictionary)
            let status = SecItemAdd(saveQuery as CFDictionary, nil)
            if status != errSecSuccess {
                throw PlanetError.KeyManagerSavingKeyError
            }
        }
    }

    func loadValue(forKey key: String, withICloudSync sync: Bool = false) throws -> String {
        let loadQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(loadQuery as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        guard let data = item as? Data else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        return value
    }
    
    func check(forKey key: String) -> Bool {
        let loadQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanFalse!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(loadQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func delete(forKey key: String, withICloudSync sync: Bool = false) throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ]
        Task(priority: .utility) {
            let status = SecItemDelete(deleteQuery as CFDictionary)
            if status != errSecSuccess {
                throw PlanetError.KeyManagerDeletingKeyError
            }
        }
    }
}
