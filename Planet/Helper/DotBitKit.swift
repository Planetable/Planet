//
//  DotBitKit.swift
//  Planet
//
//  Created by Xin Liu on 9/7/22.
//

import Foundation
import Alamofire
import SwiftyJSON

class DotBitKit: NSObject {
    static let shared = DotBitKit()
    
    static let indexerURL = URL(string: "https://indexer-v1.did.id")!
    static let accountInfoURL = indexerURL.appendingPathComponent("/v1/account/info")
    static let accountRecordsURL = indexerURL.appendingPathComponent("/v1/account/records")


    func resolve(_ account: String) async -> String? {
        let parameters = ["account": account]
        AF.request(DotBitKit.accountRecordsURL, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default).response { response in
            if let data = response.data, let json = try? JSON(data: data) {
                if let errno = json["errno"].int, errno == 0 {
                    debugPrint(json)
                }
            }
        }
        return nil
    }
}
