import Fluent
import FluentPostgresDriver
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) throws {

    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 1271
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.postgres(
        hostname: "localhost",
        port: PostgresConfiguration.ianaPortNumber,
        username: Config.shared.databaseUsername,
        password: Config.shared.databasePassword,
        database: Config.shared.databaseName
    ), as: .psql)

    app.migrations.add(User.Migration())
    try app.autoMigrate().wait()

    app.views.use(.leaf)

    try routes(app)
}
