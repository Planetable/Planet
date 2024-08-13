//
//  PlanetAPIAuthMiddleware.swift
//  Planet
//

import Foundation
import Vapor


struct PlanetAPIAuthMiddleware: AsyncMiddleware {
    let username: String
    let password: String
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let authorization = request.headers.basicAuthorization else {
            throw Abort(.unauthorized, reason: "Missing or invalid Authorization header")
        }
        if authorization.username == username && authorization.password == password {
            return try await next.respond(to: request)
        } else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
    }
}
