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
        guard usersCount == .zero else {
            try job.delete(on: app.db).wait()
            return
        }

        try Headword.query(on: app.db)
            .filter("dictionary_id", .equal, (try dictionary.requireID()))
            .delete()
            .wait()

        try Entry.query(on: app.db)
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
            job.progress = (Float(job.currentEntryIndex) / Float(entries.count)) / 2
            try job.save(on: app.db).wait()
            savedEntries.append(contentsOf: entryChunks)
        }

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
            job.progress = 0.5 + ((Float(job.currentHeadwordIndex) / Float(mkd.headwords.count)) / 2)
            try job.save(on: app.db).wait()
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

    let dictionaryName: String
    let css: String
    let darkCSS: String?
    let icon: String?
    let headwords: [Headword]
    let entries: [String]
    let type: String

}
