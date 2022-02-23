//
//  PlanetConfiguration.swift
//  Planet
//
//  Created by Kai on 1/18/22.
//

import Foundation


enum Configuration {
    enum Error: Swift.Error {
        case missingKey, invalidValue
    }

    private static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey:key) else {
            throw Error.missingKey
        }

        switch object {
        case let value as T:
            return value
        case let string as String:
            guard let value = T(string) else { fallthrough }
            return value
        default:
            throw Error.invalidValue
        }
    }
    
    static var bundlePrefix: String {
        let prefix: String
        do {
            prefix = try Configuration.value(for: "ORGANIZATION_IDENTIFIER_PREFIX")
        } catch {
            debugPrint("failed to get bundle prefix: \(error)")
            prefix = ""
        }
        return prefix
    }
}
