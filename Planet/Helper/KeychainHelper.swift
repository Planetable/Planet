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
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecUseDataProtectionKeychain: true,
            kSecAttrSynchronizable: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ] as [String: Any]
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
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ] as [String: Any]
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
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecUseDataProtectionKeychain: true,
            kSecAttrSynchronizable: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ] as [String: Any]
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
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ] as [String: Any]
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
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanFalse!,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [String: Any]
        let status = SecItemCopyMatching(loadQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func delete(forKey key: String, withICloudSync sync: Bool = false) throws {
        let deleteQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrSynchronizable: sync ? kCFBooleanTrue! : kCFBooleanFalse!
        ] as [String: Any]
        Task(priority: .utility) {
            let status = SecItemDelete(deleteQuery as CFDictionary)
            if status != errSecSuccess {
                throw PlanetError.KeyManagerDeletingKeyError
            }
        }
    }
}
