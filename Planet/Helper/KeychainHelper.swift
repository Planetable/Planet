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
    
    // MARK: - Data
    
    func saveData(_ data: Data, forKey key: String, withICloudSync sync: Bool = false) throws {
        let saveQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecUseDataProtectionKeychain: false,
            kSecAttrSynchronizable: sync
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
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: sync
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
    
    // MARK: - String
    
    func saveValue(_ value: String, forKey key: String, withICloudSync sync: Bool = false) throws {
        guard value.count > 0, let data = value.data(using: .utf8) else {
            throw PlanetError.KeyManagerSavingKeyError
        }
        let saveQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecUseDataProtectionKeychain: false,
            kSecAttrSynchronizable: sync
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
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: sync
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
    
    // MARK: -
    
    func check(forKey key: String) -> Bool {
        let loadQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: false,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [String: Any]
        let status = SecItemCopyMatching(loadQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func delete(forKey key: String, withICloudSync sync: Bool = false) throws {
        let deleteQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrSynchronizable: sync
        ] as [String: Any]
        Task(priority: .utility) {
            let status = SecItemDelete(deleteQuery as CFDictionary)
            if status != errSecSuccess {
                throw PlanetError.KeyManagerDeletingKeyError
            }
        }
    }
    
    func importKeyFile(forPlanetKeyName keyName: String, fileURL url: URL) throws {
        let keyData = try Data(contentsOf: url)
        try IPFSCommand.importKey(name: keyName, target: url, format: "pem-pkcs8-cleartext").run()
        let key = .keyPrefix + keyName
        try KeychainHelper.shared.saveData(keyData, forKey: key, withICloudSync: true)
    }
    
    func exportKeyFile(forPlanetName planetName: String, planetKeyName keyName: String, toDirectory url: URL) throws -> URL {
        let safePlanetName = planetName.sanitized()
        let targetKeyPath = url.appendingPathComponent(safePlanetName).appendingPathExtension("pem")
        if FileManager.default.fileExists(atPath: targetKeyPath.path) {
            throw PlanetError.KeyManagerExportingKeyExistsError
        }
        let tmpKeyPath = URLUtils.temporaryPath.appendingPathComponent(safePlanetName).appendingPathExtension("pem")
        defer {
            try? FileManager.default.removeItem(at: tmpKeyPath)
        }
        if FileManager.default.fileExists(atPath: tmpKeyPath.path) {
            try FileManager.default.removeItem(at: tmpKeyPath)
        }
        let (ret, _, _) = try IPFSCommand.exportKey(name: keyName, target: tmpKeyPath, format: "pem-pkcs8-cleartext").run()
        if ret != 0 {
            throw PlanetError.IPFSError
        }
        try FileManager.default.copyItem(at: tmpKeyPath, to: targetKeyPath)
        return targetKeyPath
    }

    func importKeyFromKeychain(forPlanetKeyName keyName: String) throws {
        let key = .keyPrefix + keyName
        if check(forKey: key) {
            let keyData = try loadData(forKey: key, withICloudSync: true)
            let tmpKeyPath = URLUtils.temporaryPath.appendingPathComponent(keyName).appendingPathExtension("pem")
            if FileManager.default.fileExists(atPath: tmpKeyPath.path) {
                try? FileManager.default.removeItem(at: tmpKeyPath)
            }
            try keyData.write(to: tmpKeyPath)
            defer {
                try? FileManager.default.removeItem(at: tmpKeyPath)
            }
            try IPFSCommand.importKey(name: keyName, target: tmpKeyPath, format: "pem-pkcs8-cleartext").run()
        } else {
            throw PlanetError.MissingPlanetKeyError
        }
    }
    
    func exportKeyToKeychain(forPlanetKeyName keyName: String) throws {
        let tmpKeyPath = URLUtils.temporaryPath.appendingPathComponent(keyName).appendingPathExtension("pem")
        defer {
            try? FileManager.default.removeItem(at: tmpKeyPath)
        }
        if FileManager.default.fileExists(atPath: tmpKeyPath.path) {
            try FileManager.default.removeItem(at: tmpKeyPath)
        }
        let (ret, _, _) = try IPFSCommand.exportKey(name: keyName, target: tmpKeyPath, format: "pem-pkcs8-cleartext").run()
        if ret != 0 {
            throw PlanetError.IPFSError
        }
        let keyData = try Data(contentsOf: tmpKeyPath)
        let key = .keyPrefix + keyName
        try KeychainHelper.shared.saveData(keyData, forKey: key, withICloudSync: true)
    }
}
