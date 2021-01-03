import Fluent
import Vapor

class AuthController: RouteCollection {

    struct ResetPasswordRequest: Codable, Validatable {
        let password: String
        let confirmPassword: String

        static func validations(_ validations: inout Validations) {
            validations.add("password", as: String.self, is: !.empty)
            validations.add("password", as: String.self, is: .count(6...))
        }
    }

    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")

        auth.post("resetPassword", ":userID", ":key") { req -> EventLoopFuture<User> in
            guard let userID = req.parameters.get("userID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let key = req.parameters.get("key", as: String.self) else { throw Abort(.badRequest, reason: "Key not provided") }
            try ResetPasswordRequest.validate(content: req)
            let object = try req.content.decode(ResetPasswordRequest.self)

            guard object.password == object.confirmPassword else {
                throw Abort(.badRequest, reason: "Passwords did not match")
            }

            return User.find(userID, on: req.db)
                .unwrap(orError: Abort(.notFound))
                .throwingFlatMap { user in
                    guard user.passwordResetKey == key, let resetDate = user.passwordResetDate, resetDate > Date(timeIntervalSinceNow: -60 * 60 * 2) else {
                        throw Abort(.badRequest)
                    }

                    user.passwordResetKey = nil
                    user.passwordResetDate = nil
                    user.passwordHash = try Bcrypt.hash(object.password)

                    return user.update(on: req.db)
                        .map {
                            req.auth.login(user)
                            return user
                        }
                }

        }

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
