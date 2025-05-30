//
//  PlanetAPILogMiddleware.swift
//  Planet
//

import Foundation
import Vapor


struct PlanetAPILogMiddleware: AsyncMiddleware {
    var viewModel: PlanetAPIConsoleViewModel

    init() {
        self.viewModel = PlanetAPIConsoleViewModel.shared
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let originIP: String = {
            let ipv4Pattern = #"(\d{1,3}\.){3}\d{1,3}"#
            let ipv6Pattern = #"([a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4}"#
            let headerIP = request.headers.first(name: "X-Forwarded-For") ?? ""
            let remoteIP = request.remoteAddress?.description ?? ""
            let combinedIP = headerIP.isEmpty ? remoteIP : headerIP
            if let match = combinedIP.range(of: ipv4Pattern, options: .regularExpression) {
                return String(combinedIP[match])
            } else if let match = combinedIP.range(of: ipv6Pattern, options: .regularExpression) {
                return String(combinedIP[match])
            }
            return ""
        }()
        do {
            let response = try await next.respond(to: request)
            Task.detached(priority: .background) {
                await self.viewModel.addLog(statusCode: response.status.code, originIP: originIP, requestURL: request.method.rawValue + " " + request.url.path)
            }
            return response
        } catch let error as AbortError {
            Task.detached(priority: .utility) {
                await self.viewModel.addLog(statusCode: error.status.code, originIP: originIP, requestURL: "\(request.method.rawValue) \(request.url.path)", errorDescription: error.reason)
            }
            throw error
        } catch let error as DecodingError {
            Task.detached(priority: .utility) {
                await self.viewModel.addLog(statusCode: error.status.code, originIP: originIP, requestURL: "\(request.method.rawValue) \(request.url.path)", errorDescription: error.reason)
            }
            throw error
        } catch {
            Task.detached(priority: .utility) {
                await self.viewModel.addLog(statusCode: 500, originIP: originIP, requestURL: "\(request.method.rawValue) \(request.url.path)", errorDescription: error.localizedDescription)
            }
            throw error
        }
    }
}
