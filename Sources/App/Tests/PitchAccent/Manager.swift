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
        let grouping = Swift.Dictionary(grouping: filteredEntries, by: { entry in
            entry.kana
        })
        let groupsByKana: [[PitchAccentEntry]] = Array(grouping.values).filter { $0.count > 1 }

        let groupsByKanaGroupedByAccent: [[[PitchAccentEntry]]] = groupsByKana.map { Array(Swift.Dictionary(grouping: $0, by: { $0.soloAccent }).values) }
        let minimalPairs = groupsByKanaGroupedByAccent.filter { $0.count > 1 }.map {
            MinimalPair(kana: $0[0][0].kana, pairs: $0.map { .init(pitchAccent: $0[0].accents[0].accent[0].pitchAccent, entries: $0, soundFile: $0[0].accents[0].soundFile!) })
        }
        
        let counters = entries.filter { $0.type == .counter }
        let allCounters = counters.map { Counter(id: $0.id, name: $0.kanji.count > 0 ? "\($0.kanji[0])（\($0.kana)）" : $0.kana) }

        let nameData = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/misc/random/names.yml"))
        let decoder = YAMLDecoder()
        let decoded = try! decoder.decode(RandomNames.self, from: String(data: nameData, encoding: .utf8)!)

        _shared = .init(entries: entries, minimalPairs: minimalPairs, allCounters: allCounters, counters: counters, randomNames: decoded)
    }

    let entries: [PitchAccentEntry]
    let minimalPairs: [MinimalPair]
    let allCounters: [Counter]
    let counters: [PitchAccentEntry]
    let randomNames: RandomNames

}
