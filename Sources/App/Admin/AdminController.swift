import Fluent
import SQLKit
import Vapor

extension QueryBuilder {
    public func all<T: FluentKit.Model>(as t: T.Type) -> EventLoopFuture<[T]> {
        var models: [Result<T, Error>] = []
        return self.all(as: t) { model in
            models.append(model)
        }.flatMapThrowing {
            return try models
                .map { try $0.get() }
        }
    }

    public func all<T: FluentKit.Model>(as: T.Type, _ onOutput: @escaping (Result<T, Error>) -> ()) -> EventLoopFuture<Void> {
        var all: [T] = []

        let done = self.run { output in
            onOutput(.init(catching: {
                let model = T()
                try model.output(from: output.schema(T.schema))
                all.append(model)
                return model
            }))
        }

        // if eager loads exist, run them, and update models
        if !self.eagerLoaders.isEmpty {
            return done.flatMap {
                // don't run eager loads if result set was empty
                guard !all.isEmpty else {
                    return self.database.eventLoop.makeSucceededFuture(())
                }
                // run eager loads
                return EventLoopFutureQueue(eventLoop: self.database.eventLoop).append(each: self.eagerLoaders) { loader in
                    return loader.anyRun(models: all, on: self.database)
                }.flatMapErrorThrowing { error in
                    if case .previousError(let error) = error as? EventLoopFutureQueue.ContinueError {
                        throw error
                    } else {
                        throw error
                    }
                }
            }
        } else {
            return done
        }
    }
    /// Returns a single `Page` out of the complete result set according to the supplied `PageRequest`.
    ///
    /// This method will first `count()` the result set, then request a subset of the results using `range()` and `all()`.
    /// - Parameters:
    ///     - request: Describes which page should be fetched.
    /// - Returns: A single `Page` of the result set containing the requested items and page metadata.
    public func paginate<T: FluentKit.Model>(as t: T.Type, _ request: PageRequest) -> EventLoopFuture<Page<T>> {
        let count = self.count()
        let start = (request.page - 1) * request.per
        let end = request.page * request.per
        let items = self.copy().range(start..<end).all(as: T.self)
        return items.and(count).map { (models, total) in
            Page(
                items: models,
                metadata: .init(
                    page: request.page,
                    per: request.per,
                    total: total
                )
            )
        }
    }

    public func paginate<T: FluentKit.Model>(as t: T.Type, for request: Request) -> EventLoopFuture<Page<T>> {
        do {
            let page = try request.query.decode(PageRequest.self)
            return self.paginate(as: t, page)
        } catch {
            return request.eventLoop.makeFailedFuture(error)
        }
    }
}

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

        admin.get("otherVideos") { (req: Request) -> EventLoopFuture<Page<AnkiDeckVideoResponse>> in
            let q = (try? req.query.get(String.self, at: "q"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isAudiobook = (try? req.query.get(Bool.self, at: "q")) ?? false
            guard let db = req.db as? SQLDatabase else {
                throw Abort(.internalServerError)
            }
            let page = try req.query.decode(PageRequest.self)
            let start = (page.page - 1) * page.per
            let end = page.page * page.per

            var countQuery = AnkiDeckVideo
                .query(on: req.db)
            if !q.isEmpty {
                countQuery = countQuery.filter(\.$title, .custom("LIKE"), q)
            }
            let count = countQuery.count()

            var itemsQuery = db.select()
                .column(SQLFunction("count", args: SQLLiteral.string("\(AnkiDeckSubtitle.schema).id")))
                .column(table: AnkiDeckVideo.schema, column: "id")
                .column(table: AnkiDeckVideo.schema, column: "title")
                .column(table: AnkiDeckVideo.schema, column: "source")
                .column(table: AnkiDeckVideo.schema, column: "tags")
                .from(AnkiDeckVideo.schema)
                .join(AnkiDeckSubtitle.schema, on: "\(AnkiDeckSubtitle.schema).video_id=\(AnkiDeckVideo.schema).id")
            if !q.isEmpty {
                itemsQuery = itemsQuery.where(.init("\(AnkiDeckVideo.schema).title"), .like, q)
            }
            if isAudiobook {
                itemsQuery = itemsQuery.where(SQLLiteral.string("audiobook"), .equal, SQLFunction("ANY", args: (SQLColumn("tags", table: AnkiDeckVideo.schema))))
            }
            let items = itemsQuery
                .groupBy(SQLColumn("id", table: AnkiDeckVideo.schema))
                .groupBy(SQLColumn("title", table: AnkiDeckVideo.schema))
                .groupBy(SQLColumn("source", table: AnkiDeckVideo.schema))
                .groupBy(SQLColumn("tags", table: AnkiDeckVideo.schema))
                .offset(start)
                .limit(end - start)
                .all()
                .flatMapThrowing {
                    try $0.map {
                        try $0.decode(model: AnkiDeckVideoResponse.self, keyDecodingStrategy: .convertFromSnakeCase)
                    }
                }
            return items.and(count).map { (models, total) in
                Page(
                    items: models,
                    metadata: .init(
                        page: page.page,
                        per: page.per,
                        total: total
                    )
                )
            }
        }
    }

}

final class AnkiDeckVideoResponse: Model, Content {

    static let schema = "anki_deck_videos"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "source")
    var source: String

    @Field(key: "tags")
    var tags: [String]

    @Field(key: "count")
    var count: Int

    init() {
    }

}

