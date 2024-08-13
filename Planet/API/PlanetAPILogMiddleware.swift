//
//  PlanetAPILogMiddleware.swift
//  Planet
//

import Foundation
import Vapor


struct PlanetAPILogMiddleware: AsyncMiddleware {
    var viewModel: PlanetAPILogViewModel

    init() {
        self.viewModel = PlanetAPILogViewModel.shared
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        Task.detached(priority: .background) {
            await MainActor.run {
                self.viewModel.addLog(statusCode: response.status.code, requestURL: request.method.string + " " + request.url.path)
            }
        }
        return response
    }
}
