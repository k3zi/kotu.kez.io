import Fluent
import FluentPostgresDriver
import Leaf
import Redis
import Vapor

public func configure(_ app: Application) throws {

    app.redis.configuration = try RedisConfiguration(hostname: "localhost")

    app.databases.use(.postgres(
        hostname: "localhost",
        port: PostgresConfiguration.ianaPortNumber,
        username: Config.shared.databaseUsername,
        password: Config.shared.databasePassword,
        database: Config.shared.databaseName
    ), as: .psql)

    app.migrations.add(User.Migration())
    app.migrations.add(User.Migration1())
    app.migrations.add(Language.Migration())
    app.migrations.add(Project.Migration())
    app.migrations.add(Translation.Migration())
    app.migrations.add(Subtitle.Migration())
    try app.autoMigrate().wait()

    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 1271
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(User.sessionAuthenticator())

    app.views.use(.leaf)

    try routes(app)
}
