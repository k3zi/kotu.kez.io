import FluentKit
import Foundation
import Vapor

class DictionaryInsertJobManager {

    enum Error: Swift.Error {
        case couldNotParseFormat
    }

    fileprivate static var _shared: DictionaryInsertJobManager = DictionaryInsertJobManager()

    static var shared: DictionaryInsertJobManager {
        return _shared
    }

    static let queue = DispatchQueue(label: "io.kez.kotu.dictionary")

    var isRunning = false

    func run(app: Application) {
        guard !isRunning else {
            return
        }
        DictionaryInsertJobManager.queue.async {
            try? self.internalRun(app: app)
        }
    }

    private func internalRun(app: Application) throws  {
        isRunning = true
        while true {
            let insertJob = try DictionaryInsertJob
                .query(on: app.db)
                .with(\.$dictionary) {
                    $0.with(\.$entries)
                }
                .filter(\.$isComplete == false).first().wait()
            if let insertJob = insertJob {
                do {
                    try process(job: insertJob, app: app)
                } catch {
                    insertJob.isComplete = true
                    insertJob.errorMessage = error.localizedDescription
                    try? insertJob.save(on: app.db).wait()
                }
            }

            let removeJob = try DictionaryRemoveJob
                .query(on: app.db)
                .with(\.$dictionary)
                .first().wait()
            if let removeJob = removeJob {
                do {
                    try processRemove(job: removeJob, app: app)
                } catch {
                    print(error)
                }
            }
            sleep(10)
        }
    }

    private func processRemove(job: DictionaryRemoveJob, app: Application) throws {
        guard let dictionary = job.dictionary else {
            try job.delete(on: app.db).wait()
            return
        }
        let usersCount = try dictionary.$owners.query(on: app.db).count().wait()
        guard usersCount == .zero || job.hasStarted else {
            try job.delete(on: app.db).wait()
            return
        }

        job.hasStarted = true
        try job.save(on: app.db).wait()

        try Headword.query(on: app.db)
            .filter("dictionary_id", .equal, (try dictionary.requireID()))
            .delete()
            .wait()

        let entries = try Entry.query(on: app.db)
            .filter("dictionary_id", .equal, (try dictionary.requireID()))
            .field(\.$id)
            .all()
            .wait()

        _ = entries.chunked(into: 127).concurrentMap(batchSize: 10) {
            try? Entry.query(on: app.db)
                .filter(\._$id ~~ $0.map { $0.id! })
                .delete()
                .wait()
        }

        let files = try ExternalFile.query(on: app.db)
            .filter("dictionary_id", .equal, (try dictionary.requireID()))
            .field(\.$path).field(\.$id)
            .all()
            .wait()
        let  externalFilesDirectory = URL(fileURLWithPath: app.directory.resourcesDirectory).appendingPathComponent("Files")
        _ = files.concurrentMap {
            let fileURL = externalFilesDirectory.appendingPathComponent($0.path)
            try? FileManager.default.removeItem(at: fileURL)
        }

        _ = files.chunked(into: 127).concurrentMap(batchSize: 10) {
            try? ExternalFile.query(on: app.db)
                .filter(\._$id ~~ $0.map { $0.id! })
                .delete()
                .wait()
        }

        let references = try DictionaryReference.query(on: app.db)
            .filter("dictionary_id", .equal, (try dictionary.requireID()))
            .field(\.$id)
            .all()
            .wait()

        _ = references.chunked(into: 127).concurrentMap(batchSize: 10) {
            try? DictionaryReference.query(on: app.db)
                .filter(\._$id ~~ $0.map { $0.id! })
                .delete()
                .wait()
        }

        try ExternalFile.query(on: app.db)
            .filter("dictionary_id", .equal, (try dictionary.requireID()))
            .delete()
            .wait()

        job.$dictionary.id = nil
        try job.save(on: app.db).wait()

        try dictionary.delete(on: app.db).wait()
        try job.delete(on: app.db).wait()
    }

    private func process(job: DictionaryInsertJob, app: Application) throws {
        let directory = URL(fileURLWithPath: app.directory.resourcesDirectory).appendingPathComponent("Temp").appendingPathComponent(job.tempDirectory)
        let fileURL = directory.appendingPathComponent(job.filename)
        if fileURL.pathExtension == "mkd" {
            try processMKD(job: job, app: app)
        }
    }

    private func processMKD(job: DictionaryInsertJob, app: Application) throws {
        let directory = URL(fileURLWithPath: app.directory.resourcesDirectory).appendingPathComponent("Temp").appendingPathComponent(job.tempDirectory)
        let fileURL = directory.appendingPathComponent(job.filename)
        let data = try Data(contentsOf: fileURL)
        let uncompressedData = try data.gunzipped()
        let mkd = try JSONDecoder().decode(MKD.self, from: uncompressedData)

        let parts = 2 + ((mkd.files ?? []).count > 0 ? 1 : 0) + ((mkd.references ?? []).count > 0 ? 1 : 0)
        var index = 0
        let dictionary = job.dictionary
        try dictionary.save(on: app.db).wait()
        let entries = Array(mkd.entries.enumerated())
        let remainingEntries = Array(entries.suffix(from: job.currentEntryIndex))
        let chunkedEntries = remainingEntries.chunked(into: 127)
        var savedEntries = dictionary.entries.sorted(by: { $0.index < $1.index })
        for chunk in chunkedEntries {
            let count = chunk.count
            let entryChunks = chunk.map { (i, text) in Entry(dictionary: dictionary, content: text, index: i) }
            try entryChunks.create(on: app.db).wait()
            job.currentEntryIndex += count
            job.progress = (Float(job.currentEntryIndex) / Float(entries.count)) / Float(parts)
            try job.save(on: app.db).wait()
            savedEntries.append(contentsOf: entryChunks)
        }
        index += 1

        let headwords = mkd.headwords
        let remainingHeadwords = Array(headwords.suffix(from: job.currentHeadwordIndex))
        let chunkedHeadwords = remainingHeadwords.chunked(into: 127)
        for chunk in chunkedHeadwords {
            let count = chunk.count
            let headwords = chunk.map { headword -> Headword in
                let entry = savedEntries[headword.entryIndex]
                return Headword(dictionary: dictionary, text: headword.value, headline: headword.headline, shortHeadline: headword.shortHeadline, entryIndex: headword.entryIndex, subentryIndex: headword.subentryIndex, entry: entry)
            }
            try headwords.create(on: app.db).wait()
            job.currentHeadwordIndex += count
            job.progress = (Float(index) / Float(parts)) + ((Float(job.currentHeadwordIndex) / Float(mkd.headwords.count)) / Float(parts))
            try job.save(on: app.db).wait()
        }
        index += 1

        let files = mkd.files ?? []
        let remainingFiles = Array(files.suffix(from: job.currentFileIndex))
        let chunkedFiles = remainingFiles.chunked(into: 127)
        let externalFilesDirectory = URL(fileURLWithPath: app.directory.resourcesDirectory).appendingPathComponent("Files")
        for chunk in chunkedFiles {
            let count = chunk.count
            let files = chunk.map { file -> EventLoopFuture<Void> in
                let ext = file.aliasPath.components(separatedBy: ".").last!
                guard let data = Data(base64Encoded: file.base64EncodedString) else {
                    return app.db.eventLoop.future()
                }
                let externalFile = ExternalFile(dictionary: dictionary, size: Int(data.count), path: "", aliasPath: file.aliasPath, ext: ext)
                return externalFile
                    .create(on: app.db)
                    .throwingFlatMap {
                        let uuid = try externalFile.requireID().uuidString
                        let newFilePath = externalFilesDirectory.appendingPathComponent("\(uuid).\(ext)")
                        externalFile.path = newFilePath.pathComponents.last!
                        try data.write(to: newFilePath)
                        return externalFile.update(on: app.db)
                    }
            }
            try _ = EventLoopFuture.whenAllComplete(files, on: app.db.eventLoop).wait()
            job.currentFileIndex += count
            job.progress = (Float(index) / Float(parts)) + ((Float(job.currentFileIndex) / Float(mkd.files?.count ?? 0)) / Float(parts))
            try job.save(on: app.db).wait()
        }
        if !files.isEmpty {
            index += 1
        }

        let references = mkd.references ?? []
        let remainingReferences = Array(references.suffix(from: job.currentReferenceIndex))
        let chunkedReferences = remainingReferences.chunked(into: 127)
        for chunk in chunkedReferences {
            let count = chunk.count
            let references = chunk.map {
                DictionaryReference(dictionary: dictionary, key: $0.key, entryIndex: $0.entryIndex, filePath: $0.filePath)
                    .create(on: app.db)
            }
            try _ = EventLoopFuture.whenAllComplete(references, on: app.db.eventLoop).wait()
            job.currentReferenceIndex += count
            job.progress = (Float(index) / Float(parts)) + ((Float(job.currentReferenceIndex) / Float(mkd.references?.count ?? 0)) / Float(parts))
            try job.save(on: app.db).wait()
        }
        if !references.isEmpty {
            index += 1
        }

        dictionary.css = mkd.css
        dictionary.darkCSS = mkd.darkCSS ?? ""
        dictionary.name = mkd.dictionaryName
        dictionary.icon = mkd.icon.flatMap { Data(base64Encoded: $0) }
        dictionary.type = mkd.type
        try dictionary.save(on: app.db).wait()
        try job.delete(on: app.db).wait()
        try FileManager.default.removeItem(at: fileURL)
        try FileManager.default.removeItem(at: directory)
    }

}



struct MKD: Decodable {

    struct Headword: Decodable {
        let value: String
        let headline: String
        let shortHeadline: String
        let entryIndex: Int
        let subentryIndex: Int

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            value = try container.decode(String.self)
            headline = try container.decode(String.self)
            shortHeadline = try container.decode(String.self)
            entryIndex = try container.decode(Int.self)
            subentryIndex = try container.decode(Int.self)
        }
    }

    struct File: Decodable {
        let aliasPath: String
        let base64EncodedString: String

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            aliasPath = try container.decode(String.self)
            base64EncodedString = try container.decode(String.self)
        }
    }

    struct Reference: Decodable {
        let key: String
        let entryIndex: Int?
        let filePath: String?

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            key = try container.decode(String.self)
            if let string = try? container.decode(String.self) {
                entryIndex = nil
                filePath = string
            } else {
                entryIndex = try container.decode(Int.self)
                filePath = nil
            }
        }
    }

    let dictionaryName: String
    let css: String
    let darkCSS: String?
    let icon: String?
    let headwords: [Headword]
    let entries: [String]
    let files: [File]?
    let references: [Reference]?
    let type: String

}
