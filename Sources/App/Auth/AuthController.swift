import Fluent
import Vapor

class AuthController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")

        let credentialsProtectedRoute = auth.grouped(User.credentialsAuthenticator())
        credentialsProtectedRoute.post("login") { req -> User in
            return try req.auth.require(User.self)
        }

        credentialsProtectedRoute.get("logout") { req -> Response in
            try req.auth.require(User.self)
            req.auth.logout(User.self)
            return Response(status: .ok)
        }

        auth.post("register") { (req: Request) -> EventLoopFuture<User> in
            try User.Create.validate(content: req)
            let object = try req.content.decode(User.Create.self)
            guard object.password == object.confirmPassword else {
                throw Abort(.badRequest, reason: "Passwords did not match")
            }

            let user = try User(
                username: object.username,
                passwordHash: Bcrypt.hash(object.password)
            )
            return user.save(on: req.db)
                .map { user }
                .always { result in
                    guard case let .success(user) = result else { return }
                    req.auth.login(user)
                }
        }
    }

}
