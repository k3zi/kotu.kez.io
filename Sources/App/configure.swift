import Fluent
import FluentPostgresDriver
import Leaf
import Redis
import Vapor
import VaporSecurityHeaders

public func configure(_ app: Application) throws {

    app.redis.configuration = try RedisConfiguration(hostname: "127.0.0.1")
    app.sessions.use(.redis)

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
    app.migrations.add(Fragment.Migration())
    app.migrations.add(Subtitle.Migration1())
    app.migrations.add(Project.Migration1())
    app.migrations.add(Invite.Migration())
    app.migrations.add(Share.Migration())
    app.migrations.add(Headword.Migration())
    try app.autoMigrate().wait()

    try app.db.schema("dictionary_headwords").delete().wait()
    try app.db.schema("dictionary_headwords")
        .id()
        .field("text", .string, .required)
        .field("headline", .string, .required)
        .field("short_headline", .string, .required)
        .field("entry_index", .int, .required)
        .field("subentry_index", .int, .required)
        .create()
        .wait()

    let directoryURL = URL(fileURLWithPath: app.directory.workingDirectory)

    let shortHeadlineStoreData = try Data(contentsOf: directoryURL.appendingPathComponent("Resources/SMK8/headline/short-headline.headlinestore"))
    let shortHeadlineStore = try HeadlineStore.parse(tokenizer: DataTokenizer(data: shortHeadlineStoreData))

    let headlineStoreData = try Data(contentsOf: directoryURL.appendingPathComponent("Resources/SMK8/headline/headline.headlinestore"))
    let headlineStore = try HeadlineStore.parse(tokenizer: DataTokenizer(data: headlineStoreData))

    let keyStoreData = try Data(contentsOf: directoryURL.appendingPathComponent("Resources/SMK8/key/headword.keystore"))
    let headWordKeyStore = try KeyStore.parse(tokenizer: DataTokenizer(data: keyStoreData))

    let headwords = headWordKeyStore.pairs
        .flatMap { headword in
            headword.matches.map { match -> Headword in
                let headline = headlineStore.headlines.first { $0.index == match.entryIndex && $0.subindex == match.subentryIndex }
                let shortHeadline = shortHeadlineStore.headlines.first { $0.index == match.entryIndex && $0.subindex == match.subentryIndex }
                return Headword(text: headword.value, headline: headline?.text ?? "", shortHeadline: shortHeadline?.text ?? "", entryIndex: Int(match.entryIndex), subentryIndex: Int(match.subentryIndex))
            }
        }
   try headwords
        .chunked(into: 127)
        .forEach { try $0.create(on: app.db).wait() }

    DictionaryManager.preload()

    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 1271

    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(User.sessionAuthenticator())

    app.views.use(.leaf)

    try routes(app)
}
