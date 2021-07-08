import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Foundation
import Vapor
import ZIPFoundation

// TODO: Find a better place to put this.
func importAnkiDeck(app: Application, fileURL: URL) throws {
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

func handleAnkiDecks(app: Application) throws {
    let directoryURL = URL(fileURLWithPath: app.directory.workingDirectory)
    let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL.appendingPathComponent("../Decks"), includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "apkg" }
        .sorted(by: { $0.path < $1.path })

    for fileURL in fileURLs {
        try? importAnkiDeck(app: app, fileURL: fileURL)
    }
}
