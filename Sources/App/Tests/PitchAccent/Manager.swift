import Vapor

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

        _shared = .init(entries: entries, minimalPairs: minimalPairs)
    }

    let entries: [PitchAccentEntry]
    let minimalPairs: [MinimalPair]

}
