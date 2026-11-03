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
        guard let (_, resp) = try? await URLSession.shared.data(from: url)
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
        guard let _ = resp as? HTTPURLResponse else {
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

// MARK: - Pushing the IPNS record (2026-11-03)
//
// A DHT node keeps an IPNS record for 36 hours after it received it, and only
// the publisher's node puts it back, every 4 hours, while it runs. Pinnable
// keeps each site's best record and re-puts it, so the name resolves while
// this Mac is off. Pushing the record right after a publish makes the new
// version live at once instead of on Pinnable's next check. The record is
// the signed document the local Kubo just wrote; no key leaves the Mac.
// Pinnable's side: technotes/pin-api.md in the Pinnable repo.

extension Pinnable {
    static let recordLimit = 2048

    /// Post the record the local Kubo holds for `ipns` to Pinnable. Failures
    /// are logged and ignored: Pinnable's checker picks the record up later.
    func pushRecord(ipns: String) async {
        guard let url = URL(string: api + "/record") else {
            debugPrint("Push IPNS record to Pinnable: Incorrect URL")
            return
        }
        guard let record = await Self.localRecord(ipns: ipns) else {
            debugPrint("Push IPNS record to Pinnable: the local node has no record for \(ipns)")
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        let boundary = "planet-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"record\"; filename=\"record\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(record)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
            let httpResp = resp as? HTTPURLResponse
        else {
            debugPrint("Push IPNS record to Pinnable: Unexpected URLResponse")
            return
        }
        let answer = String(data: data, encoding: .utf8) ?? ""
        debugPrint("Push IPNS record to Pinnable: HTTP \(httpResp.statusCode) \(answer)")
    }

    /// The record bytes the local Kubo holds for `/ipns/<ipns>`, from `routing/get`.
    static func localRecord(ipns: String) async -> Data? {
        guard
            let data = try? await IPFSDaemon.shared.api(
                path: "routing/get",
                args: ["arg": "/ipns/\(ipns)"],
                timeout: 30
            )
        else {
            return nil
        }
        return recordFromRoutingGet(data)
    }

    /// `routing/get` answers lines of JSON; the record is the line of `Type` 5,
    /// base64 in `Extra`. Nothing, or too long, gives nil.
    static func recordFromRoutingGet(_ data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        for line in text.split(separator: "\n") {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                (object["Type"] as? Int) == 5,
                let extra = object["Extra"] as? String,
                let record = Data(base64Encoded: extra),
                !record.isEmpty, record.count <= recordLimit
            else {
                continue
            }
            return record
        }
        return nil
    }
}
