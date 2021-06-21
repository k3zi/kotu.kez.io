import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Gatekeeper
import IkigaJSON
import Leaf
import Redis
import Vapor
import ZIPFoundation

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

    let directoryURL = URL(fileURLWithPath: app.directory.workingDirectory)
//    let directoryName = "SMK8"
//    let dictionaryName = "新明解第八版"
//    let dictionaryVersion = "3"
//    let dictionaryType = "ja"
//    let dictionaryURL = directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)")
////
////    let bzippedOutputData = try Data(contentsOf: directoryURL.appendingPathComponent("Taishukan-G5.mkd"))
////    let bunzippedOutputData = try bzippedOutputData.gunzipped()
////    var boutput: [String: Any] = try JSONSerialization.jsonObject(with: bunzippedOutputData) as! [String : Any]
////    boutput["type"] = "en-ja"
////
////    let aoutputData = try JSONSerialization.data(withJSONObject: boutput)
////    let azippedOutputData = try aoutputData.gzipped(level: .bestCompression)
////    try azippedOutputData.write(to: directoryURL.appendingPathComponent("aTaishukan-G5.mkd"))
//
//
//// For saving dictionary headlines to JSON.
//
//    var files = [String: Data]()
//    var references = [String: Any]()
//    var lists = [String: [Any]]()
//
//    let contentsDirectory = directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/contents")
//    let fileContainer = try CompressedFileContainer(withDirectory: contentsDirectory)
//    let contentIndexData = try Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/contents/contents.idx"))
//    let contentIndex = try ContentIndex.parse(tokenizer: .init(data: contentIndexData))
//
//    for (key, value) in contentIndex.indexMapping {
//        guard key != value else { continue }
//        references[String(key)] = value
//    }
//
//
////    let exportedFolder = contentsDirectory.appendingPathComponent("exported", isDirectory: true)
////    try FileManager.default.createDirectory(at: exportedFolder, withIntermediateDirectories: true)
////    for (i, file) in fileContainer.files.enumerated() {
////        let outputFileURL = exportedFolder.appendingPathComponent("\(String(format: "%05d", i)).html")
////        try file.text.data(using: .utf8)!.write(to: outputFileURL)
////    }
////    let headlineStoreData = try Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/SMK8/headline/headline.headlinestore"))
////    let headlineStore = try HeadlineStore.parse(tokenizer: DataTokenizer(data: headlineStoreData))
////    let data = try! JSONEncoder().encode(headlineStore.headlines.filter { $0.subindex > 20480 }.map { $0.text })
////    try! data.write(to: directoryURL.appendingPathComponent("listOfAllHeadlineUsages.json"))
//
//
////
////    try Dictionary.query(on: app.db)
////        .filter(\.$name == dictionaryName)
////        .delete()
////        .wait()
////    let dictionary = oldDictionary ?? Dictionary(name: dictionaryName, directoryName: directoryName)
////    if dictionary.id == nil {
////        try dictionary.create(on: app.db).wait()
////    }
////
////    // For saving HTML files to folder
////    let contentsDirectory = directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/contents")
////    let fileContainer = try CompressedFileContainer(withDirectory: contentsDirectory)
////    let exportedFolder = contentsDirectory.appendingPathComponent("exported", isDirectory: true)
////    try FileManager.default.createDirectory(at: exportedFolder, withIntermediateDirectories: true)
////    for (i, file) in fileContainer.files.enumerated() {
////        let outputFileURL = exportedFolder.appendingPathComponent("\(String(format: "%05d", i)).html")
////        try file.text.data(using: .utf8)!.write(to: outputFileURL)
////    }
////
////    // For saving content mapping
////    let contentIndexData = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/contents/contents.idx"))
////    let contentIndex = try! ContentIndex.parse(tokenizer: .init(data: contentIndexData))
////    try JSONSerialization.data(withJSONObject: contentIndex.indexMapping.map { ["key": $0.key, "value": $0.value]}).write(to: directoryURL.appendingPathComponent("content-mapping.json"))
////
////    try Headword.query(on: app.db)
////        .filter("dictionary_id", .equal, try dictionary.requireID())
////        .delete().wait()
//
//    let shortHeadlineStore = try HeadlineStore.parse(dictionaryFolder: dictionaryURL, short: true)
//    let headlineStore = try HeadlineStore.parse(dictionaryFolder: dictionaryURL)!
//    let headWordKeyStore = try KeyStore.parse(dictionaryFolder: dictionaryURL)!
//
//    let headlinesDict = Swift.Dictionary(grouping: headlineStore.headlines, by: { $0.index })
//    let shortHeadlinesDict = shortHeadlineStore.flatMap { Swift.Dictionary(grouping: $0.headlines, by: { $0.index }) }
//    let headwords = headWordKeyStore.pairs.concurrentFlatMap { headword in
//        headword.matches.map { match -> [Any] in
//            let headline = headlinesDict[match.entryIndex]?.first { $0.subindex == match.subentryIndex }
//            let shortHeadline = shortHeadlinesDict?[match.entryIndex]?.first { $0.subindex == match.subentryIndex }
//            return [headword.value, headline?.text ?? "", shortHeadline?.text ?? "", contentIndex.indexMapping[Int(match.entryIndex)]!, Int(match.subentryIndex)]
//        }
//    }
//    let entries = fileContainer.files.map { $0.text }
//
//    let audioDirectory = dictionaryURL.appendingPathComponent("audio")
//    let audioContainer = try? CompressedDataFileContainer(withDirectory: audioDirectory)
//    for file in audioContainer?.files ?? [] {
//        files["\(file.filename).aac"] = file.data
//    }
//
//    if let enumerator = FileManager.default.enumerator(at: dictionaryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
//        let dictionaryAbsolutePath = (try? dictionaryURL.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath ?? dictionaryURL.path
//        for case let fileURL as URL in enumerator {
//            let filename = fileURL.path.suffix(from: dictionaryAbsolutePath.endIndex).dropFirst()
//            guard !["icon.png", "style.css", "dark_style.css"].contains(filename) else { continue }
//            if ["png", "jpg", "svg", "html", "css"].contains(fileURL.pathExtension) {
//                let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
//                if fileAttributes.isRegularFile! {
//                    files[String(filename)] = try Data(contentsOf: fileURL)
//                }
//            } else if fileURL.pathExtension == "entries" {
//                let listIndex = try ListIndex.parse(tokenizer: DataTokenizer(data: Data(contentsOf: fileURL)))
//                lists[String(filename)] = listIndex.items.concurrentMap { item in
//                    let headline = headlinesDict[UInt(item.entryIndex)]?.first { $0.subindex == item.subentryIndex } ?? headlinesDict[UInt(item.entryIndex)]?.first { $0.subindex == 0 }
//                    let shortHeadline = shortHeadlinesDict?[UInt(item.entryIndex)]?.first { $0.subindex == item.subentryIndex } ?? shortHeadlinesDict?[UInt(item.entryIndex)]?.first { $0.subindex == 0 }
//                    return [headline?.text ?? "", shortHeadline?.text ?? "", contentIndex.indexMapping[Int(item.entryIndex)]!, Int(item.subentryIndex)]
//                }
//            }
//        }
//    }
//
//    let cssData = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/style.css"))
//    let css = String(data: cssData, encoding: .utf8)!
//    let darkCSSData = try? Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/dark_style.css"))
//    let darkCSS = darkCSSData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
//
//    let output: [String: Any] = [
//        "dictionaryName": dictionaryName,
//        "version": dictionaryVersion,
//        "type": dictionaryType,
//        "css": css,
//        "darkCSS": darkCSS,
//        "icon":
//            (try Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(directoryName)/icon.png"))).base64EncodedString(),
//        "headwords": headwords,
//        "entries": entries,
//        "files": files.map { [$0.key, $0.value.base64EncodedString()] },
//        "references": references.map { [$0.key, $0.value] },
//        "lists": lists.map { [$0.key, $0.value] }
//    ]
////
////    try headwords
////         .chunked(into: 127)
////         .forEach { try $0.create(on: app.db).wait() }
//
//    let outputData = try JSONSerialization.data(withJSONObject: output)
//    let zippedOutputData = try outputData.gzipped(level: .bestCompression)
//    try zippedOutputData.write(to: directoryURL.appendingPathComponent("\(dictionaryName).mkd"))

    func importAnkiDeck(fileURL: URL) throws {
        var deckName = (fileURL.pathComponents.last ?? "")
        deckName.removeLast(5)
        print("Anki Deck: \(deckName)")
        let existingDeck = try AnkiDeckVideo.query(on: app.db).filter(\.$title == deckName).first().wait()
        guard existingDeck == nil else {
            return
        }

        let tempDirectory = URL(fileURLWithPath: app.directory.resourcesDirectory).appendingPathComponent("Temp")
        let externalFilesDirectory = URL(fileURLWithPath: app.directory.resourcesDirectory).appendingPathComponent("Files")

        try? FileManager.default.createDirectory(at: externalFilesDirectory, withIntermediateDirectories: true)
        let uuid = UUID().uuidString
        let folderDirectory = tempDirectory.appendingPathComponent(uuid)
        let databaseURL = folderDirectory.appendingPathComponent("collection.anki2")
        let mediaURL = folderDirectory.appendingPathComponent("media")

        try? FileManager.default.createDirectory(at: folderDirectory, withIntermediateDirectories: true)
        guard let archive = Archive(url: fileURL, accessMode: .read, preferredEncoding: .utf8), let collectionAnki2 = archive["collection.anki2"], let media = archive["media"] else {
            return
        }
        _ = try archive.extract(collectionAnki2, to: databaseURL)
        _ = try archive.extract(media, to: mediaURL)
        let mediaMappingData = try Data(contentsOf: mediaURL)
        guard let rawMediaMapping = try JSONSerialization.jsonObject(with: mediaMappingData, options: []) as? [String: String] else {
            return
        }
        var mediaMapping = [String: Int]()
        for pair in rawMediaMapping {
            if let key = Int(pair.key) {
                mediaMapping[pair.value] = key
            }
        }
        mediaMapping = mediaMapping.filter { $0.key.hasSuffix("mp3") || $0.key.hasSuffix("m4a") }
        let mediaIDs = mediaMapping.values.sorted()
        for id in mediaIDs {
            _ = try archive.extract(archive[String(id)]!, to: folderDirectory.appendingPathComponent(String(id)))
        }

        app.databases.use(.sqlite(.file(databaseURL.path)), as: .init(string: uuid))
        let db = app.db(.init(string: uuid))
        let notes = try Anki.Note.query(on: db).all().wait()
        var subtitles = [(String, String)]()
        for note in notes {
            let fields = note.fields.components(separatedBy: String(UnicodeScalar(UInt8(31))))
            let allFieldsValue = String(fields.flatMap { $0 })
            guard let soundFile = Array(Set(allFieldsValue.match("\\[sound:(.*?)\\]").compactMap { String($0[1]) })).filter({ $0.count > 0 }).first else {
                continue
            }
            guard let text = fields.map { $0.replacingOccurrences(of: "</div>", with: "").replacingOccurrences(of: "<div>", with: "") }.filter({ !$0.contains("<") && !$0.contains("[") && !$0.contains("(") && !$0.contains("_") && $0.match("[\u{3040}-\u{30ff}\u{3400}-\u{4dbf}\u{4e00}-\u{9fff}\u{f900}-\u{faff}\u{ff66}-\u{ff9f}]").count > 0 }).first else {
                continue
            }
            subtitles.append((soundFile, text))
        }

        let video = AnkiDeckVideo(title: deckName)
        try video.create(on: app.db).wait()

        let futures = try subtitles.map { soundFile, text -> EventLoopFuture<Void> in
            guard let mediaID = mediaMapping[soundFile] else {
                return app.db.eventLoop.future()
            }
            let filePath = folderDirectory.appendingPathComponent(String(mediaID))
            let fileSize: UInt64
            let attr = try FileManager.default.attributesOfItem(atPath: filePath.path)
            let ext = soundFile.components(separatedBy: ".").last!
            fileSize = attr[FileAttributeKey.size] as! UInt64
            let externalFile = ExternalFile(size: Int(fileSize), path: "", ext: ext)
            return externalFile
                .create(on: app.db)
                .throwingFlatMap {
                    let uuid = try externalFile.requireID().uuidString
                    let newFilePath = externalFilesDirectory.appendingPathComponent("\(uuid).\(ext)")
                    externalFile.path = newFilePath.pathComponents.last!
                    try FileManager.default.moveItem(at: filePath, to: newFilePath)
                    return externalFile.update(on: app.db)
                }
                .flatMap {
                    AnkiDeckSubtitle(video: video, text: text, externalFile: externalFile)
                        .create(on: app.db)
                }
        }
        try futures
            .chunked(into: 127)
            .forEach {
                _ = try EventLoopFuture.whenAllSucceed($0, on: app.db.eventLoop).wait()
            }
        app.databases.reinitialize(.init(string: uuid))
        try FileManager.default.removeItem(at: folderDirectory)
    }

    func handleAnkiDecks() throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL.appendingPathComponent("../Decks"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "apkg" }
            .sorted(by: { $0.path < $1.path })

        for fileURL in fileURLs {
            try? importAnkiDeck(fileURL: fileURL)
        }
    }

    ankiDeckQueue.async {
        try! handleAnkiDecks()
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

extension IkigaJSONEncoder: ContentEncoder {
    public func encode<E: Encodable>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws {
        headers.contentType = .json
        try self.encodeAndWrite(encodable, into: &body)
    }
}

extension IkigaJSONDecoder: ContentDecoder {
    public func decode<D: Decodable>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D {
        guard headers.contentType == .json || headers.contentType == .jsonAPI else {
            throw Abort(.unsupportedMediaType)
        }

        return try self.decode(D.self, from: body)
    }
}
