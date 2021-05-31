import Vapor
import Yams

struct RandomNames: Decodable {

    struct Name: Decodable, Encodable {
        let kanji: String
        let hiragana: String
        let katakana: String

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            kanji = try container.decode(String.self)
            hiragana = try container.decode(String.self)
            katakana = try container.decode(String.self)
        }
    }

    struct FirstName: Decodable {
        let male: [Name]
        let female: [Name]
    }

    enum CodingKeys: String, CodingKey {
        case firstNames = "first_name"
        case lastNames = "last_name"
    }

    let firstNames: FirstName
    let lastNames: [Name]
}

struct Counter: Content {
    let id: String
    let name: String
}

struct PitchAccentManager {

    fileprivate static var _shared: PitchAccentManager?

    static var shared: PitchAccentManager {
        return _shared!
    }

    static func configure(app: Application) -> Void {
        let directory = app.directory.workingDirectory
        let directoryURL = URL(fileURLWithPath: directory)
        let data = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/NHK_ACCENT/entries.json"))
        let entries = try! JSONDecoder().decode([PitchAccentEntry].self, from: data)
        let filteredEntries = entries.filter { !$0.accents.isEmpty && $0.accents[0].soundFile != nil }
        let groupingByKana = Swift.Dictionary(grouping: filteredEntries, by: { entry in
            entry.kana
        })
        let groupsByKana: [[PitchAccentEntry]] = Array(groupingByKana.values).filter { $0.count > 1 }
        let groupsByID = Swift.Dictionary(grouping: entries, by: { $0.id }).mapValues { $0.first! }

        let groupsByKanaGroupedByAccent: [[[PitchAccentEntry]]] = groupsByKana.concurrentMap { Array(Swift.Dictionary(grouping: $0, by: { $0.soloAccent }).values) }
        let minimalPairs = groupsByKanaGroupedByAccent.filter { $0.count > 1 }.concurrentMap {
            MinimalPair(kana: $0[0][0].kana, pairs: $0.map { .init(pitchAccent: $0[0].accents[0].accent[0].pitchAccent, entries: $0, soundFile: $0[0].accents[0].soundFile!) })
        }

        let syllabaryMinimalPairsData = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/misc/syllabaryMinimalPairs.json"))
        let syllabaryMinimalPairIDs = try! JSONDecoder().decode([[String]].self, from: syllabaryMinimalPairsData)
        let syllabaryMinimalPairs = syllabaryMinimalPairIDs.map { $0.map { groupsByID[$0]! } }.map {
            SyllabaryMinimalPair(pitchAccent: $0[0].accents[0].accent[0].pitchAccent, pairs: $0)
        }.filter { $0.kind != .none }

//        let groupingByAccentAndLength = Swift.Dictionary(grouping: filteredEntries, by: { entry in
//            entry.soloAccent
//        })
//        let groupsByAccentAndLength: [[PitchAccentEntry]] = Array(groupingByAccentAndLength.values).filter { $0.count > 1 }
//        let syllabaryMinimalPairs = groupsByAccentAndLength.concurrentMap(batchSize: 1024) { group -> [SyllabaryMinimalPair] in
//            return (0..<group.count).concurrentMap(batchSize: 1024) { i -> [SyllabaryMinimalPair] in
//                let x = group[i]
//                guard x.accents.count == 1, x.accents[0].accent.count == 1 else { return [SyllabaryMinimalPair]() }
//                var pairs = [SyllabaryMinimalPair]()
//                for j in (i + 1)..<group.count {
//                    let y = group[j]
//                    guard y.accents.count == 1, y.accents[0].accent.count == 1 else { continue }
//                    if x.accents[0].accent[0].pronunciation.isMinimalPair(with: y.accents[0].accent[0].pronunciation) {
//                        pairs.append(SyllabaryMinimalPair(pitchAccent: y.accents[0].accent[0].pitchAccent, pairs: [x, y]))
//                    }
//                }
//                return pairs
//            }.flatMap { $0 }
//        }.flatMap { $0 }
        // po JSONSerialization.data(withJSONObject: (syllabaryMinimalPairs.map { [$0.pairs[0].id, $0.pairs[1].id] } as [[String]]), options: []).write(to: URL(fileURLWithPath: app.directory.workingDirectory).appendingPathComponent("testssss.json"))

        let counters = entries.filter { $0.type == .counter }
        let allCounters = counters.concurrentMap { Counter(id: $0.id, name: "\($0.kanji.count > 0 ? "\($0.kanji[0]) (\($0.kana))" : $0.kana)\($0.usage.flatMap { " (\($0))" } ?? "")") }

        let nameData = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/misc/random/names.yml"))
        let decoder = YAMLDecoder()
        let decoded = try! decoder.decode(RandomNames.self, from: String(data: nameData, encoding: .utf8)!)

        _shared = .init(entries: entries, minimalPairs: minimalPairs, syllabaryMinimalPairs: syllabaryMinimalPairs, allCounters: allCounters, counters: counters, randomNames: decoded)
    }

    let entries: [PitchAccentEntry]
    let minimalPairs: [MinimalPair]
    let syllabaryMinimalPairs: [SyllabaryMinimalPair]
    let allCounters: [Counter]
    let counters: [PitchAccentEntry]
    let randomNames: RandomNames

}
