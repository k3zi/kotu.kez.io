import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Gatekeeper
import IkigaJSON
import Leaf
import Redis
import Vapor

let ankiDeckQueue = DispatchQueue(label: "io.kez.kotu.setup.anki")

public func configure(_ app: Application) throws {
    app.redis.configuration = try RedisConfiguration(hostname: "127.0.0.1")
    app.sessions.use(.redis)

    app.routes.defaultMaxBodySize = "1gb"
    app.http.server.configuration.responseCompression = .enabled
    app.http.server.configuration.requestDecompression = .enabled(limit: .none)
    app.http.server.configuration.supportPipelining = true
    app.http.server.configuration.serverName = "kotu"

    var decoder = IkigaJSONDecoder()
    decoder.settings.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    var encoder = IkigaJSONEncoder()
    encoder.settings.encodeNilAsNull = true
    encoder.settings.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)

    app.databases.use(.postgres(
        hostname: "localhost",
        port: PostgresConfiguration.ianaPortNumber,
        username: Config.shared.databaseUsername,
        password: Config.shared.databasePassword,
        database: Config.shared.databaseName,
        maxConnectionsPerEventLoop: 32
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
    app.migrations.add(Dictionary.Migration())
    app.migrations.add(Headword.Migration1())

    app.migrations.add(Deck.Migration())
    app.migrations.add(NoteType.Migration())
    app.migrations.add(Note.Migration())
    app.migrations.add(NoteField.Migration())
    app.migrations.add(NoteFieldValue.Migration())
    app.migrations.add(CardType.Migration())
    app.migrations.add(Card.Migration())
    app.migrations.add(File.Migration())
    app.migrations.add(User.Migration2(), User.Migration3(), User.Migration5(), User.Migration6(), User.Migration7())
    app.migrations.add(Share.Migration2())
    app.migrations.add(Invite.Migration1())
    app.migrations.add(ListWord.Migration(), ListWord.Migration1(), ListWord.Migration2(), ListWord.Migration3())
    app.migrations.add(User.Migration8())
    app.migrations.add(User.Migration9())
    app.migrations.add(Feedback.Migration())
    app.migrations.add(Note.Migration1())
    app.migrations.add(Feedback.Migration1())
    app.migrations.add(User.Migration10())
    app.migrations.add(UserToken.Migration())
    app.migrations.add(BlogPost.Migration(), BlogPost.Migration1())
    app.migrations.add(Card.Migration1())
    app.migrations.add(Deck.Migration1())
    app.migrations.add(Deck.Migration2())
    app.migrations.add(YouTubeVideo.Migration(), YouTubeSubtitle.Migration(), YouTubeSubtitle.Migration1())
    app.migrations.add(Note.Migration2())
    app.migrations.add(NoteType.Migration1())
    app.migrations.add(ExternalFile.Migration(), AnkiDeckVideo.Migration(), AnkiDeckSubtitle.Migration())
    app.migrations.add(ExternalFile.Migration1())
    app.migrations.add(ReaderSession.Migration(), ReaderSession.Migration1(), ReaderSession.Migration2(), ReaderSession.Migration3(), ReaderSession.Migration4())
    app.migrations.add(DictionaryOwner.Migration(), Dictionary.Migration1(), Entry.Migration(), Headword.Migration2(), DictionaryInsertJob.Migration(), Dictionary.Migration2(), Entry.Migration1())
    app.migrations.add(Dictionary.Migration3())
    app.migrations.add(DictionaryRemoveJob.Migration())
    app.migrations.add(ReviewLog.Migration(), ReviewLog.Migration1())
    app.migrations.add(DictionaryOwner.Migration1())
    app.migrations.add(AnkiDeckVideo.Migration1(), AnkiDeckSubtitle.Migration1(), AnkiDeckVideo.Migration2())
    app.migrations.add(User.Migration11(), User.Migration12())
    app.migrations.add(DictionaryInsertJob.Migration1(), ExternalFile.Migration2(), DictionaryRemoveJob.Migration1())
    app.migrations.add(DictionaryInsertJob.Migration2(), DictionaryReference.Migration())
    app.migrations.add(ReaderSession.Migration5())
    app.migrations.add(ReaderSession.Migration6())
    app.migrations.add(ReaderSession.Migration7())
    app.migrations.add(ReaderSession.Migration8())
    app.migrations.add(ReaderSession.Migration9())
    app.migrations.add(Card.Migration2(), Card.Migration3())
    app.migrations.add(Deck.Migration3())
    app.migrations.add(ReaderSession.Migration10())
    app.migrations.add(Note.Migration3())
    app.migrations.add(Feedback.Migration2())

    try app.autoMigrate().wait()
    try DictionaryManager.configure(app: app).wait()
    DictionaryInsertJobManager.shared.run(app: app)
    PitchAccentManager.configure(app: app)

    ankiDeckQueue.async {
        try! handleAnkiDecks(app: app)
        print("Finished importing decks.")
    }

    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 1271

    app.caches.use(.memory)
    app.gatekeeper.config = .init(maxRequests: 10, per: .second)
    app.gatekeeper.keyMakers.use(.hostname)

    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(User.sessionAuthenticator())
    app.middleware.use(UserToken.authenticator())

    app.views.use(.leaf)

    try routes(app)
}
