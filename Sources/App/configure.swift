import Fluent
import FluentPostgresDriver
import Leaf
import Redis
import Vapor

public func configure(_ app: Application) throws {

    app.redis.configuration = try RedisConfiguration(hostname: "127.0.0.1")
    app.sessions.use(.redis)

    app.routes.defaultMaxBodySize = "100mb"
    app.http.server.configuration.responseCompression = .enabled
    app.http.server.configuration.requestDecompression = .enabled
    app.http.server.configuration.supportPipelining = true

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

    try app.autoMigrate().wait()

// For saving dictionary headlines to JSON.
//    let directoryURL = URL(fileURLWithPath: app.directory.workingDirectory)
//    let contentsDirectory = directoryURL.appendingPathComponent("Resources/Dictionaries/NHK_ACCENT/contents")
//    let fileContainer = try CompressedFileContainer(withDirectory: contentsDirectory)
//    let exportedFolder = contentsDirectory.appendingPathComponent("exported", isDirectory: true)
//    try FileManager.default.createDirectory(at: exportedFolder, withIntermediateDirectories: true)
//    for (i, file) in fileContainer.files.enumerated() {
//        let outputFileURL = exportedFolder.appendingPathComponent("\(String(format: "%05d", i)).html")
//        try file.text.data(using: .utf8)!.write(to: outputFileURL)
//    }
//    let headlineStoreData = try Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/SMK8/headline/headline.headlinestore"))
//    let headlineStore = try HeadlineStore.parse(tokenizer: DataTokenizer(data: headlineStoreData))
//    let data = try! JSONEncoder().encode(headlineStore.headlines.filter { $0.subindex > 20480 }.map { $0.text })
//    try! data.write(to: directoryURL.appendingPathComponent("listOfAllHeadlineUsages.json"))

//    let directoryURL = URL(fileURLWithPath: app.directory.workingDirectory)
//    let directoryName = "Taishukan-GJE3"
//
//    let oldDictionary = try Dictionary.query(on: app.db)
//        .filter(\.$name == "ジーニアス和英辞典")
//        .first()
//        .wait()
//    let dictionary = oldDictionary ?? Dictionary(name: "ジーニアス和英辞典", directoryName: directoryName)
//    if dictionary.id == nil {
//        try dictionary.create(on: app.db).wait()
//    }
//
//    try Headword.query(on: app.db)
//        .filter("dictionary_id", .equal, try dictionary.requireID())
//        .delete().wait()
//
////    let shortHeadlineStoreData = try Data(contentsOf: directoryURL.appendingPathComponent("Resources/Dictionaries/\(directoryName)/headline/short-headline.headlinestore"))
////    let shortHeadlineStore = try HeadlineStore.parse(tokenizer: DataTokenizer(data: shortHeadlineStoreData))
////
//    let headlineStoreData = try Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/headline/headline.headlinestore"))
//    let headlineStore = try HeadlineStore.parse(tokenizer: DataTokenizer(data: headlineStoreData))
//
//    let keyStoreData = try Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/key/headword.keystore"))
//    let headWordKeyStore = try KeyStore.parse(tokenizer: DataTokenizer(data: keyStoreData))
//
//    let headwords = headWordKeyStore.pairs
//        .flatMap { headword in
//            headword.matches.map { match -> Headword in
//                let headline = headlineStore.headlines.first { $0.index == match.entryIndex && $0.subindex == match.subentryIndex }
//                return Headword(dictionary: dictionary, text: headword.value, headline: headline?.text ?? "", shortHeadline: headline?.text ?? "", entryIndex: Int(match.entryIndex), subentryIndex: Int(match.subentryIndex))
//            }
//        }
//
//   try headwords
//        .chunked(into: 127)
//        .forEach { try $0.create(on: app.db).wait() }

    try DictionaryManager.configure(app: app).wait()
    PitchAccentManager.configure(app: app)

    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 1271

    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    app.middleware.use(User.sessionAuthenticator())
    app.middleware.use(UserToken.authenticator())

    app.views.use(.leaf)

    try routes(app)
}
