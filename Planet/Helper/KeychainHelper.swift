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
    
    private var appServiceName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "ORGANIZATION_IDENTIFIER_PREFIX") as? String {
            return name + ".Planet"
        }
        return "xyz.planetable.Planet"
    }
    
    private var appICloudSync: Bool {
        return true
    }
    
    // MARK: - Data
    
    func saveData(_ data: Data, forKey key: String) throws {
        let saveQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: appServiceName,
            kSecValueData: data,
            kSecUseDataProtectionKeychain: true,
            kSecAttrSynchronizable: appICloudSync
        ] as [String: Any]
        Task(priority: .utility) {
            SecItemDelete(saveQuery as CFDictionary)
            let status = SecItemAdd(saveQuery as CFDictionary, nil)
            if status != errSecSuccess {
                throw PlanetError.KeyManagerSavingKeyError
            }
        }
    }

    func loadData(forKey key: String) throws -> Data {
        let loadQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: appServiceName,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: appICloudSync
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
    
    func saveValue(_ value: String, forKey key: String) throws {
        guard value.count > 0, let data = value.data(using: .utf8) else {
            throw PlanetError.KeyManagerSavingKeyError
        }
        try saveData(data, forKey: key)
    }

    func loadValue(forKey key: String) throws -> String {
        let data = try loadData(forKey: key)
        guard let value = String(data: data, encoding: .utf8) else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        return value
    }
    
    // MARK: - Actions: Check Status
    
    func check(forKey key: String) -> Bool {
        let loadQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: appServiceName,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: appICloudSync
        ] as [String: Any]
        let status = SecItemCopyMatching(loadQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Actions: Delete

    func delete(forKey key: String) throws {
        let deleteQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrSynchronizable: appICloudSync
        ] as [String: Any]
        Task(priority: .utility) {
            let status = SecItemDelete(deleteQuery as CFDictionary)
            if status != errSecSuccess {
                throw PlanetError.KeyManagerDeletingKeyError
            }
        }
    }
    
    // MARK: - Actions: Import Key from target directory to Keystore and Keychain

    func importKeyFile(forPlanetKeyName keyName: String, fileURL url: URL) throws {
        let keyData = try Data(contentsOf: url)
        try IPFSCommand.importKey(name: keyName, target: url, format: "pem-pkcs8-cleartext").run()
        try saveData(keyData, forKey: keyName)
    }
    
    // MARK: - Actions: Export Key from Keystore to target directory

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

    // MARK: - Actions: Import Key from Keychain to Keystore
    
    func importKeyFromKeychain(forPlanetKeyName keyName: String) throws {
        if check(forKey: keyName) {
            let keyData = try loadData(forKey: keyName)
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
    
    // MARK: - Actions: Export Key from Keystore to Keychain
    
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
        try saveData(keyData, forKey: keyName)
    }
}
