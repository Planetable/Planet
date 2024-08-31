//
//  String+EthereumChecksumAddress.swift
//  Planet
//
//  Created by Xin Liu on 8/30/24.
//

import CryptoSwift
import Foundation

extension String {
    /// Checks if the string is a valid Ethereum address, including checksum verification.
    var isValidEthereumAddress: Bool {
        // Ensure the address starts with "0x" and has exactly 42 characters
        guard self.hasPrefix("0x"), self.count == 42 else {
            return false
        }

        // Extract the address part after "0x"
        let addressPart = self.dropFirst(2)

        // Define the characters allowed in a hexadecimal string
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")

        // Ensure all characters in the address are valid hexadecimal characters
        guard addressPart.unicodeScalars.allSatisfy({ hexCharacterSet.contains($0) }) else {
            return false
        }

        // Check if the address is all lowercase or all uppercase
        if addressPart == addressPart.lowercased() || addressPart == addressPart.uppercased() {
            return true
        }

        // Validate the checksum address
        return self.isChecksumAddress
    }

    /// Checks if the string is a valid checksummed Ethereum address according to EIP-55.
    private var isChecksumAddress: Bool {
        let address = self.dropFirst(2)  // Remove the '0x' prefix
        let lowercasedAddress = address.lowercased()

        // Calculate the keccak256 hash of the lowercase hexadecimal address
        guard let hash = lowercasedAddress.keccak256() else {
            return false
        }

        for (index, character) in address.enumerated() {
            let hashCharacter = hash[hash.index(hash.startIndex, offsetBy: index)]
            let value = Int(String(hashCharacter), radix: 16)!

            // Check if the character matches the checksum condition
            if character.isLetter {
                if value >= 8 && character.isLowercase {
                    return false
                }
                if value < 8 && character.isUppercase {
                    return false
                }
            }
        }

        return true
    }
}

extension String {
    /// Computes the Keccak-256 hash of the string.
    func keccak256() -> String? {
        guard let data = self.data(using: .utf8) else { return nil }
        let hash = SHA3(variant: .keccak256).calculate(for: Array(data))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

extension Character {
    var isUppercase: Bool {
        return self >= "A" && self <= "F"
    }

    var isLowercase: Bool {
        return self >= "a" && self <= "f"
    }
}
