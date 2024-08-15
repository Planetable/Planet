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
        do {
            let response = try await next.respond(to: request)
            Task.detached(priority: .background) {
                await MainActor.run {
                    self.viewModel.addLog(statusCode: response.status.code, requestURL: request.method.string + " " + request.url.path)
                }
            }
            return response
        } catch let error as AbortError {
            Task.detached(priority: .background) {
                await MainActor.run {
                    self.viewModel.addLog(statusCode: error.status.code, requestURL: "\(request.method.string) \(request.url.path)")
                }
            }
            throw error
        } catch {
            Task.detached(priority: .background) {
                await MainActor.run {
                    self.viewModel.addLog(statusCode: 500, requestURL: "\(request.method.string) \(request.url.path)")
                }
            }
            throw error
        }
    }
}
