import Fluent
import Vapor

class AuthController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")

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
        }
    }

}
