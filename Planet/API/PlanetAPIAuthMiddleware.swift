//
//  PlanetAPIAuthMiddleware.swift
//  Planet
//

import Foundation
import Vapor


struct PlanetAPIAuthMiddleware: Middleware {
    let username: String
    let password: String

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let authorization = request.headers.basicAuthorization else {
            return request.eventLoop.future(error: Abort(.unauthorized, reason: "Missing or invalid Authorization header"))
        }
        if authorization.username == username && authorization.password == password {
            return next.respond(to: request)
        } else {
            return request.eventLoop.future(error: Abort(.unauthorized, reason: "Invalid credentials"))
        }
    }
}
