import Foundation
import SwiftyJSON

public enum JSONRPCError: Error {
    case NetworkError(response: URLResponse, data: Data)
    case InvalidJSONRPCParams
    case InvalidJSONRPCResponse
}

public enum JSONRPCResponse {
    case result(JSON)
    case error(JSON)
}

public protocol JSONRPC {
    func request(method: String, params: JSON) async throws -> JSONRPCResponse
}

public extension JSONRPC {
    func buildRequestBody(_ method: String, _ params: JSON) throws -> JSON {
        guard params.string == nil, params.number == nil, params.bool == nil else {
            throw JSONRPCError.InvalidJSONRPCParams
        }

        var requestBody: JSON = [
            "jsonrpc": "2.0",
            "method": method,
            "id": Int.random(in: 0...65535),
        ]
        if params != JSON.null {
            requestBody["params"] = params
        }
        return requestBody
    }

    func getResponseResult(_ data: Data) throws -> JSONRPCResponse {
        let responseBody = try JSON(data: data)

        guard responseBody["jsonrpc"] == "2.0" else {
            throw JSONRPCError.InvalidJSONRPCResponse
        }
        if responseBody["error"].exists() {
            return JSONRPCResponse.error(responseBody["error"])
        }
        if responseBody["result"].exists() {
            return JSONRPCResponse.result(responseBody["result"])
        }
        throw JSONRPCError.InvalidJSONRPCResponse
    }
}

public struct EthereumAPI: JSONRPC {
    // WARNING: While Cloudflare Ethereum Gateway can be the most accessible, it does not support data older than 128
    //          blocks, which makes `eth_getLogs` useless
    public static let Cloudflare = EthereumAPI(url: URL(string: "https://cloudflare-eth.com/")!)
    public static let Flashbots = EthereumAPI(url: URL(string: "https://rpc.flashbots.net/")!)
    
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func request(method: String, params: JSON) async throws -> JSONRPCResponse {
        let requestBody = try buildRequestBody(method, params)

        let payload = try requestBody.rawData()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.httpBody = payload

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.ok
        else {
            throw JSONRPCError.NetworkError(response: response, data: data)
        }
        return try getResponseResult(data)
    }
}
