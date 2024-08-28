import Foundation
import Vapor

struct PlanetAPIAuthMiddleware: AsyncMiddleware {
    let username: String
    let password: String
    let realm: String = "Planet API Server"

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let authorization = request.headers.basicAuthorization else {
            return Response(
                status: .unauthorized,
                headers: [
                    "WWW-Authenticate": "Basic realm=\"\(realm)\""
                ]
            )
        }

        if authorization.username == username && authorization.password == password {
            return try await next.respond(to: request)
        }
        else {
            return Response(
                status: .unauthorized,
                headers: [
                    "WWW-Authenticate": "Basic realm=\"\(realm)\""
                ]
            )
        }
    }
}
