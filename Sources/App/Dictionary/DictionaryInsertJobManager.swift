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

    static let queue = DispatchQueue(label: "io.kez.kotu.dictionary.insert")

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
            let job = try DictionaryInsertJob
                .query(on: app.db)
                .with(\.$dictionary) {
                    $0.with(\.$entries)
                }
                .filter(\.$isComplete == false).first().wait()
            if let job = job {
                do {
                    try process(job: job, app: app)
                } catch {
                    job.isComplete = true
                    job.errorMessage = error.localizedDescription
                    try? job.save(on: app.db).wait()
                }
            }
            sleep(10)
        }
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
        dictionary.css = mkd.css
        dictionary.name = mkd.dictionaryName
        let entries = Array(mkd.entries.enumerated())
        let remainingEntries = Array(entries.suffix(from: job.currentEntryIndex))
        let chunkedEntries = remainingEntries.chunked(into: 127)
        var savedEntries = dictionary.entries.sorted(by: { $0.index < $1.index })
        for chunk in chunkedEntries {
            let count = chunk.count
            let entryChunks = chunk.map { (i, text) in Entry(dictionary: dictionary, content: text, index: i) }
            try entryChunks.create(on: app.db).wait()
            job.currentEntryIndex += count
            try job.save(on: app.db).wait()
            savedEntries.append(contentsOf: entryChunks)
        }

        let headwords = mkd.headwords
        let remainingHeadwords = Array(headwords.suffix(from: job.currentEntryIndex))
        let chunkedHeadwords = remainingHeadwords.chunked(into: 127)
        for chunk in chunkedHeadwords {
            let count = chunk.count
            let headwords = chunk.compactMap { headword -> Headword? in
                let entry = savedEntries[headword.entryIndex]
                return Headword(dictionary: dictionary, text: headword.value, headline: headword.headline, shortHeadline: headword.shortHeadline, entryIndex: headword.entryIndex, subentryIndex: headword.subentryIndex, entry: entry)
            }
            try headwords.create(on: app.db).wait()
            job.currentHeadwordIndex += count
            try job.save(on: app.db).wait()
        }

        job.isComplete = true
        try job.save(on: app.db).wait()
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
    let headwords: [Headword]
    let entries: [String]
    let type: String
}
