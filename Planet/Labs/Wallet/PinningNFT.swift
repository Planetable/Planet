//
//  PinningNFT.swift
//  Planet
//

import Foundation
import Web3

/// Unlocks the NFT tier dock icons for wallets that hold Planetable Pinning NFT Series A (PNA) tokens.
///
/// PNA token IDs are `tier × 1_000_000_000 + serial`, with serials counting up from 1 without gaps.
/// The contract can't list an owner's tokens, so the check asks `balanceOf` first, and only for
/// holders asks Multicall3 who owns each token ID, one page of serials per tier at a time. Both are
/// plain `eth_call`s on mainnet, which every public RPC server in `EthereumChainID.rpcURLs` answers.
enum PinningNFT {
    static let tiers = [1, 2, 3]

    private static let contract = try! EthereumAddress(hex: "0x3f98e2b3237a61348585c9bdb30a5571ff59cc41", eip55: false)
    private static let multicall3 = try! EthereumAddress(hex: "0xcA11bde05977b3631167028862bE2a173976CA11", eip55: false)
    private static let balanceOfSelector: [UInt8] = [0x70, 0xa0, 0x82, 0x31]
    private static let ownerOfSelector: [UInt8] = [0x63, 0x52, 0x21, 0x1e]
    /// `tryAggregate(bool requireSuccess, (address target, bytes callData)[] calls)`
    private static let tryAggregateSelector: [UInt8] = [0xbc, 0xe3, 0x8b, 0xd7]
    private static let pageSize = 64

    private static let lock = NSLock()
    private static var checkedAddresses: Set<String> = []

    enum Failure: Error {
        case malformedResponse
    }

    /// Checks the wallet once per launch and unlocks the icon for each tier it holds.
    static func unlockIcons(for walletAddress: String) async {
        let key = walletAddress.lowercased()
        guard beginCheck(key) else { return }
        guard !allTiersUnlocked() else {
            debugPrint("PNA check skipped: all tier icons are already unlocked")
            return
        }
        do {
            let held = try await heldTiers(by: walletAddress)
            debugPrint("PNA tiers held by \(walletAddress): \(held.sorted())")
            for tier in held.sorted() {
                try IconManager.shared.unlockIcon(byIDString: String(tier))
            }
        } catch {
            debugPrint("Failed to check PNA ownership for \(walletAddress): \(error)")
            // Let the next refresh try again.
            lock.lock()
            checkedAddresses.remove(key)
            lock.unlock()
        }
    }

    /// The tiers of the PNA tokens the wallet currently owns.
    static func heldTiers(by walletAddress: String) async throws -> Set<Int> {
        let owner = try EthereumAddress(hex: walletAddress, eip55: false)
        let balance = try word(at: 0, in: try await call(contract, balanceOfSelector + addressWord(owner)))
        guard balance > 0 else { return [] }

        var held: Set<Int> = []
        var found = 0
        var openTiers = tiers
        var firstSerial = 1
        while !openTiers.isEmpty && found < balance {
            let serials = Array(firstSerial..<(firstSerial + pageSize))
            let tokenIDs = openTiers.flatMap { tier in serials.map { tokenID(tier: tier, serial: $0) } }
            let owners = try await ownersOf(tokenIDs)
            var stillOpen: [Int] = []
            for (index, tier) in openTiers.enumerated() {
                let page = owners[(index * pageSize)..<((index + 1) * pageSize)]
                for tokenOwner in page where tokenOwner == owner.rawAddress {
                    held.insert(tier)
                    found += 1
                }
                // Serials have no gaps, so a tier continues only if its last serial on this page exists.
                if let lastOwner = page.last, lastOwner != nil {
                    stillOpen.append(tier)
                }
            }
            openTiers = stillOpen
            firstSerial += pageSize
        }
        return held
    }

    private static func beginCheck(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return checkedAddresses.insert(key).inserted
    }

    private static func allTiersUnlocked() -> Bool {
        let icons = IconManager.shared.dockIcons.filter { tiers.contains($0.id) }
        return !icons.isEmpty && icons.allSatisfy { $0.verifyIconStatus() }
    }

    private static func tokenID(tier: Int, serial: Int) -> UInt64 {
        return UInt64(tier) * 1_000_000_000 + UInt64(serial)
    }

    /// The owner of each token, or nil when the token doesn't exist.
    private static func ownersOf(_ tokenIDs: [UInt64]) async throws -> [[UInt8]?] {
        let calls = tokenIDs.map { ownerOfSelector + uintWord($0) }
        let results = try decodeTryAggregate(try await call(multicall3, encodeTryAggregate(target: contract, calls: calls)))
        guard results.count == tokenIDs.count else { throw Failure.malformedResponse }
        return results.map { result in
            guard result.success, result.data.count == 32 else { return nil }
            return Array(result.data[12..<32])
        }
    }

    private static func call(_ to: EthereumAddress, _ data: [UInt8]) async throws -> [UInt8] {
        let result: EthereumData = try await EthereumChainID.mainnet.rpc { web3, completion in
            web3.eth.call(call: EthereumCall(to: to, data: EthereumData(data)), block: .latest, response: completion)
        }
        return result.bytes
    }

    // MARK: - ABI

    private static func uintWord(_ value: UInt64) -> [UInt8] {
        return [UInt8](repeating: 0, count: 24) + withUnsafeBytes(of: value.bigEndian) { Array($0) }
    }

    private static func addressWord(_ address: EthereumAddress) -> [UInt8] {
        return [UInt8](repeating: 0, count: 12) + address.rawAddress
    }

    /// Encodes `tryAggregate(false, calls)` where every call goes to `target`.
    private static func encodeTryAggregate(target: EthereumAddress, calls: [[UInt8]]) -> [UInt8] {
        let tuples: [[UInt8]] = calls.map { callData in
            let padding = [UInt8](repeating: 0, count: (32 - callData.count % 32) % 32)
            return addressWord(target) + uintWord(64) + uintWord(UInt64(callData.count)) + callData + padding
        }
        var offsets: [UInt8] = []
        var position = 32 * tuples.count
        for tuple in tuples {
            offsets += uintWord(UInt64(position))
            position += tuple.count
        }
        return tryAggregateSelector + uintWord(0) + uintWord(64) + uintWord(UInt64(tuples.count))
            + offsets + tuples.flatMap { $0 }
    }

    /// Decodes the `(bool success, bytes returnData)[]` that `tryAggregate` returns.
    private static func decodeTryAggregate(_ data: [UInt8]) throws -> [(success: Bool, data: [UInt8])] {
        let array = try word(at: 0, in: data)
        let count = try word(at: array, in: data)
        let base = array + 32
        return try (0..<count).map { index in
            let start = base + (try word(at: base + 32 * index, in: data))
            let success = try word(at: start, in: data) != 0
            let bytesStart = start + (try word(at: start + 32, in: data))
            let length = try word(at: bytesStart, in: data)
            guard bytesStart + 32 + length <= data.count else { throw Failure.malformedResponse }
            return (success, Array(data[(bytesStart + 32)..<(bytesStart + 32 + length)]))
        }
    }

    /// Reads a 32-byte word as an Int, rejecting values too large to be an offset, length or count.
    private static func word(at offset: Int, in data: [UInt8]) throws -> Int {
        guard offset >= 0, offset + 32 <= data.count, data[offset..<(offset + 24)].allSatisfy({ $0 == 0 })
        else { throw Failure.malformedResponse }
        var value: UInt64 = 0
        for byte in data[(offset + 24)..<(offset + 32)] {
            value = value << 8 | UInt64(truncatingIfNeeded: byte)
        }
        guard value <= UInt64(Int32.max) else { throw Failure.malformedResponse }
        return Int(value)
    }
}
