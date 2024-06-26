//
//  WCTransaction.swift
//  Planet
//
//  Created by Xin Liu on 6/25/24.
//

import Foundation

/// https://docs.walletconnect.org/json-rpc-api-methods/ethereum#parameters-4
public struct WCTransaction: Codable {
    public var from: String
    public var to: String?
    public var data: String
    public var gas: String?
    public var gasPrice: String?
    public var value: String?
    public var nonce: String?
    public var type: String?
    public var accessList: [AccessListItem]?
    public var chainId: String?
    public var maxPriorityFeePerGas: String?
    public var maxFeePerGas: String?

    /// https://eips.ethereum.org/EIPS/eip-2930
    public struct AccessListItem: Codable {
        public var address: String
        public var storageKeys: [String]

        public init(address: String, storageKeys: [String]) {
            self.address = address
            self.storageKeys = storageKeys
        }
    }

    public init(from: String,
                to: String?,
                data: String,
                gas: String?,
                gasPrice: String?,
                value: String?,
                nonce: String?,
                type: String?,
                accessList: [AccessListItem]?,
                chainId: String?,
                maxPriorityFeePerGas: String?,
                maxFeePerGas: String?) {
        self.from = from
        self.to = to
        self.data = data
        self.gas = gas
        self.gasPrice = gasPrice
        self.value = value
        self.nonce = nonce
        self.type = type
        self.accessList = accessList
        self.chainId = chainId
        self.maxPriorityFeePerGas = maxPriorityFeePerGas
        self.maxFeePerGas = maxFeePerGas
    }
}
