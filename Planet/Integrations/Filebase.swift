//
//  Filebase.swift
//  Planet
//
//  Created by Xin Liu on 9/21/22.
//

import Foundation
import SwiftyJSON

struct Filebase: Codable {
    var pinName: String
    var apiToken: String

    func pin(cid: String) async {
        guard let url = URL(string: "https://api.filebase.io/v1/ipfs/pins") else {
            debugPrint("Filebase: failed to construct the API URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            debugPrint("Filebase: request to find existing request ID failed")
            return
        }
        var requestID: String?
        do {
            let json = try JSON(data: data)
            debugPrint("Filebase: JSON object for finding existing requestID: \(json)")
            if let results = json["results"].array {
                for result in results {
                    if let name = result["pin"]["name"].string, name == pinName {
                        requestID = result["requestid"].string
                        debugPrint("Filebase: request ID for \(pinName) found: \(requestID)")
                        break
                    }
                }
                if requestID == nil {
                    debugPrint("Filebase: request ID for \(pinName) not found")
                }
            }
        }
        catch {
            debugPrint("Filebase: error occurred when finding request ID for \(pinName) \(error)")
        }

        let parameters: [String : String] = ["name": pinName, "cid": cid]
        let jsonData = try? JSONSerialization.data(withJSONObject: parameters)

        var url2: URL?
        if let requestID = requestID {
            url2 = URL(string: "https://api.filebase.io/v1/ipfs/pins/\(requestID)")
        } else {
            url2 = URL(string: "https://api.filebase.io/v1/ipfs/pins")
        }

        guard let urlPin = url2 else { return }

        var request2 = URLRequest(url: urlPin)
        request2.httpMethod = "POST"
        request2.httpBody = jsonData
        request2.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request2.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        let data2: Data
        let response2: URLResponse
        do {
            (data2, response2) = try await URLSession.shared.data(for: request2)
        } catch {
            debugPrint("Filebase: failed to send POST request")
            return
        }
        if !(response2 as! HTTPURLResponse).ok {
            debugPrint("Filebase: http response is non-200 \(response2)")
            return
        }
        if let json = try? JSON(data: data2) {
            debugPrint("Filebase: got response: \(json)")
        } else {
            debugPrint("Filebase: failed to parse JSON response")
        }
    }
}
