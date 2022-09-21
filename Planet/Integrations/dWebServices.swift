//
//  dWebServices.swift
//  Planet
//
//  Created by Xin Liu on 9/21/22.
//

import Foundation
import SwiftyJSON

struct dWebServices: Codable {
    var domain: String
    var apiKey: String

    func publish(cid: String) async {
        guard let url = URL(string: "https://dwebservices.xyz/api/eth-names-ipns/?name=\(domain)") else {
            debugPrint("dWebServices: failed to construct the initial URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            debugPrint("dWebServices: request to find UID failed")
            return
        }
        var uid: String?
        do {
            let json = try JSON(data: data)
            if let status = json["status"].string, status == "ok" {
                if let data = json["data"][0].dictionary, let id = data["uid"]?.string {
                    uid = id
                    debugPrint("dWebServices: uid for \(domain) found: \(uid)")
                }
                else {
                    debugPrint("dWebServices: uid for \(domain) not found")
                    return
                }
            }
        }
        catch {
            debugPrint("dWebServices: error occurred when updating planet \(error)")
        }

        guard let uid = uid, let url2 = URL(string: "https://dwebservices.xyz/api/eth-names-ipns/\(uid)/publish/\(cid)/") else {
            return
        }
        var request2 = URLRequest(url: url2)
        request2.httpMethod = "GET"
        request2.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request2.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let (data2, _) = try? await URLSession.shared.data(for: request2) else {
            return
        }
        do {
            let json = try JSON(data: data2)
            debugPrint("dWebServices: \(json)")
            if let status = json["status"].string, status == "ok" {
                debugPrint("dWebServices: planet published successfully")
            }
        }
        catch {
            debugPrint("dWebServices: error occurred when publishing planet \(error)")
        }
    }
}
