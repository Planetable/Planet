//
//  Pinnable.swift
//  Planet
//
//  Created by Xin Liu on 5/2/23.
//

import Foundation

struct Pinnable {
    var api: String

    func pin() async {
        // Call Pinnable.xyz API endpoint like this:
        // https://dev.pinnable.xyz/pin/:uuid
        guard let url = URL(string: api) else {
            debugPrint("Call Pinnable.xyz API: Incorrect URL")
            return
        }
        guard let (data, resp) = try? await URLSession.shared.data(from: url)
        else {
            debugPrint("Call Pinnable.xyz API: Unexpected URLResponse")
            return
        }
        guard let httpResp = resp as? HTTPURLResponse else {
            debugPrint("Call Pinnable.xyz API: Invalid HTTPResponse")
            return
        }
        guard httpResp.statusCode == 202 else {
            debugPrint("Call Pinnable.xyz API: Unexpected HTTP Status Code \(httpResp.statusCode)")
            return
        }
    }

    func status() async -> PinnablePinStatus? {
        let apiForStatus = api.appending("/status")
        guard let url = URL(string: apiForStatus) else {
            debugPrint("Check Pinnable.xyz Pin Status: Incorrect API URL for checking status")
            return nil
        }
        debugPrint("Check Pinnable.xyz Pin Status: \(apiForStatus)")
        guard let (data, resp) = try? await URLSession.shared.data(from: url)
        else {
            debugPrint("Check Pinnable.xyz Pin Status: Unexpected URLResponse")
            return nil
        }
        guard let httpResp = resp as? HTTPURLResponse else {
            debugPrint("Check Pinnable.xyz Pin Status: Invalid HTTPResponse")
            return nil
        }
        // decode PinnablePinStatus from data
        guard
            let status: PinnablePinStatus = try? JSONDecoder().decode(
                PinnablePinStatus.self,
                from: data
            )
        else {
            debugPrint("Check Pinnable.xyz Pin Status: Failed to decode JSON")
            return nil
        }
        return status
    }
}

struct PinnablePinStatus: Codable {
    let status: String
    let last_known_ipns: String?
    let last_known_cid: String?
    let size: Int?
    let created: Int?
    let last_checked: Int?
    let last_pinned: Int?
}
