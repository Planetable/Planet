//
//  PlanetAPILogMiddleware.swift
//  Planet
//

import Foundation
import Vapor


struct PlanetAPILogMiddleware: Middleware {
    var viewModel: PlanetAPILogViewModel

    init() {
        self.viewModel = PlanetAPILogViewModel.shared
    }

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        let requestLog = "Received request: \(request.method.string) \(request.url.path)"
        Task.detached(priority: .background) {
            await MainActor.run {
                self.viewModel.addLog(requestLog)
            }
        }
        return next.respond(to: request).map { response in
            let responseLog = "Response status: \(response.status.code)"
            Task.detached(priority: .background) {
                await MainActor.run {
                    self.viewModel.addLog(responseLog)
                }
            }
            return response
        }
    }
}
