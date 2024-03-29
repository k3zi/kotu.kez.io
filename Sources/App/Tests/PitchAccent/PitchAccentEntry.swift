import Vapor

struct PitchAccentEntry: Content {

    enum Kind: String, Content {
        case headword
        case reference
        case compound
        case counter
    }

    struct AccentGroup: Content {

        struct Accent: Content {
            let pitchAccent: Int
            let silencedMora: [Int]
            let pronunciation: String
            let notes: [String]
            let notStandardButPermissible: Bool
        }

        let notStandardButPermissible: Bool
        let accent: [Accent]
        let soundFile: String?

    }

    struct Subentry: Content {
        let number: String?
        let accents: [AccentGroup]
    }

    let id: String
    let kana: String
    let kanji: [String]
    let kanjiRaw: [String]
    let usage: String?
    let category: String?
    let accents: [AccentGroup]
    let subentries: [Subentry]
    let type: Kind
    let moraCount: Int

    var soloAccent: Int {
        let a = accents[0].accent[0].pitchAccent
        if a == moraCount { // just return odaka words as flat
            return 0
        }
        return a
    }

}

struct MinimalPair: Content {

    struct Pair: Content {
        let pitchAccent: Int
        let entries: [PitchAccentEntry]
        let soundFile: String

        init(pitchAccent: Int, entries: [PitchAccentEntry], soundFile: String) {
            self.pitchAccent = pitchAccent
            self.entries = entries
            self.soundFile = soundFile
        }
    }

    let kana: String
    let pairs: [Pair]

    init(kana: String, pairs: [Pair]) {
        self.kana = kana
        self.pairs = pairs
    }
}

struct SyllabaryMinimalPair: Content {

    enum Kind: String, Content, CaseIterable {
        case none

        case tsuContrastSu
        case doContrastRo, daContrastRa, deContrastRe
        // case giContrastNi, geContrastNe

        case shortContrastLongVowel, shortContrastLongConsonant
    }

    let pitchAccent: Int
    let pairs: [PitchAccentEntry]
    let kind: Kind

    init(pitchAccent: Int, pairs: [PitchAccentEntry], kind: Kind) {
        self.pitchAccent = pitchAccent
        self.pairs = pairs
        self.kind = kind
    }

    init(pitchAccent: Int, pairs: [PitchAccentEntry]) {
        self.pitchAccent = pitchAccent
        self.pairs = pairs
        self.kind = pairs[0].accents[0].accent[0].pronunciation.minimalPair(with: pairs[1].accents[0].accent[0].pronunciation)
    }

}
