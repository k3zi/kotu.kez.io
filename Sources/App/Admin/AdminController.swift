import Fluent
import SQLKit
import Vapor

final class GuardPermissionMiddleware: Middleware {

    let permission: Permission

    init(require permission: Permission) {
        self.permission = permission
    }

    public func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let user = req.auth.get(User.self) else {
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "\(Self.self) not authenticated."))
        }

        guard user.permissions.contains(permission.rawValue) else {
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "\(Self.self) authorized for permission: \(permission)."))
        }

        return next.respond(to: req)
    }

}

class AdminController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let admin = routes.grouped("admin")
            .grouped(User.guardMiddleware())
            .grouped(GuardPermissionMiddleware(require: .admin))

        admin.get("feedback") { (req: Request) -> EventLoopFuture<[Feedback]> in
            return Feedback
                .query(on: req.db)
                .sort(\.$createdAt)
                .all()
        }

        admin.get("users") { (req: Request) -> EventLoopFuture<Page<User>> in
            return User
                .query(on: req.db)
                .sort(\.$createdAt)
                .paginate(for: req)
        }

        struct GroupedUsers: Content {
            let count: Int
            let createdAt: Date?
        }
        admin.get("numberOfUsersGroupedByDate") { req -> EventLoopFuture<[GroupedUsers]> in
            guard let db = req.db as? SQLDatabase else {
                throw Abort(.internalServerError)
            }
            return db.select()
                .column(SQLFunction("count", args: SQLLiteral.all))
                .column("created_at")
                .from(User.schema)
                .groupBy("created_at")
                .all()
                .flatMapThrowing {
                    try $0.map {
                        try $0.decode(model: GroupedUsers.self, keyDecodingStrategy: .convertFromSnakeCase)
                    }
                }
        }

        admin.post("user", ":userID", "resetPassword") { (req: Request) -> EventLoopFuture<String> in
            guard let userID = req.parameters.get("userID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            return User
                .find(userID, on: req.db)
                .unwrap(orError: Abort(.notFound))
                .flatMap { user in
                    user.passwordResetDate = .init()
                    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                    let key = String((0..<28).compactMap { _ in letters.randomElement() })
                    user.passwordResetKey = key
                    return user.update(on: req.db)
                        .map { key }
                }
        }

        admin.put("user", ":userID", "permission", ":permission", ":value") { (req: Request) -> EventLoopFuture<String> in
            guard let userID = req.parameters.get("userID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let permission = req.parameters.get("permission", as: Permission.self) else { throw Abort(.badRequest, reason: "Permission not provided") }
            guard let value = req.parameters.get("value", as: String.self) else { throw Abort(.badRequest, reason: "Value not provided") }
            let valueBool = value == "true"
            return User
                .find(userID, on: req.db)
                .unwrap(orError: Abort(.notFound))
                .flatMap { user in
                    if valueBool && !user.permissions.contains(permission.rawValue) {
                        user.permissions.append(permission.rawValue)
                    } else if !valueBool {
                        user.permissions.removeAll(where: { $0 == permission.rawValue })
                    }
                    return user.update(on: req.db)
                        .map { "Updated." }
                }
        }
    }

}

