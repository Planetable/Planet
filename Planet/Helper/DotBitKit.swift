//
//  DotBitKit.swift
//  Planet
//
//  Created by Xin Liu on 9/7/22.
//

import Foundation
import Alamofire
import SwiftyJSON


enum DWebRecordType: Int, Codable {
    case ipfs = 0
    case ipns = 1
}

struct DWebRecord: Codable {
    var type: DWebRecordType
    var value: String
}

class DotBitKit: NSObject {
    static let shared = DotBitKit()

    static let indexerURL = URL(string: "https://indexer-v1.did.id")!
    static let accountInfoURL = indexerURL.appendingPathComponent("/v1/account/info")
    static let accountRecordsURL = indexerURL.appendingPathComponent("/v1/account/records")

    func resolve(_ account: String) async -> DWebRecord? {
        if account.count > 4 {
            let parameters = ["account": account]
            let jsonData = try? JSONSerialization.data(withJSONObject: parameters)

            var request = URLRequest(url: DotBitKit.accountRecordsURL)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                return nil
            }
            if !(response as! HTTPURLResponse).ok {
                return nil
            }
            if let json = try? JSON(data: data) {
                if let errno = json["errno"].int, errno == 0 {
                    for record in json["data"]["records"].arrayValue {
                        debugPrint("\(record)")
                        let key = record["key"].stringValue
                        let value = record["value"].stringValue
                        if key.hasPrefix("dweb") {
                            if key.hasSuffix("ipns") {
                                return DWebRecord(type: .ipns, value: value)
                            }
                            if key.hasSuffix("ipfs") {
                                return DWebRecord(type: .ipfs, value: value)
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}
