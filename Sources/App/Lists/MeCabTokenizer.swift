import Foundation
import MeCab
import FluentKit
import NIO
import Vapor

protocol ExceptionResolver {

    func resolve(tokenizer: MeCabTokenizer)

}

extension Node {

    func prepending(node: Node) -> Node {
        var features = self.features
        for i in 6...11 {
            features[i] = node.features[i] + features[i]
        }
        for i in 20...23 {
            features[i] = node.features[i] + features[i]
        }
        return Node(surface: node.surface + surface, features: features, type: type)
    }

}

struct DeAruExceptionResolver: ExceptionResolver {

    func resolve(tokenizer: MeCabTokenizer) {
        if tokenizer.next.id == "22916" && tokenizer.nextNext?.id == "1216" {
            let de = tokenizer.consume()
            let aru = tokenizer.consume()
            var new = aru.prepending(node: de)
            new.features[24] = "2"
            tokenizer.nodes.insert(new, at: .zero)
        }
    }

}

struct PitchAccentResolver: ExceptionResolver {

    func isPostNoun(node: Node) -> Bool {
        node.partOfSpeech == "助動詞" || node.partOfSpeech == "助詞"
    }

    func resolve(tokenizer: MeCabTokenizer) {
        // MARK: Compound Correction
        // 語 → 平板：日本語・英語・スペイン語
        if tokenizer.next.id == "13334" {
            tokenizer.nodes[0].features[25] = "C4"
        }
        // さん → 前部のアクセント
        if tokenizer.next.id == "14495" {
            tokenizer.nodes[0].features[25] = "C5"
        }

        //  MARK: Usage Correction
        // もう一回 モー・イッカイ
        // もう言った モ＼ー・イッタ
        if tokenizer.next.id == "37569" {
            tokenizer.nodes[0].features[24] = tokenizer.nextNext?.partOfSpeechSubType == "数詞" ? "0" : "1"
        }

        // そうだね
        // そういうことか
        if ["20935", "11822", "68"].contains(tokenizer.next.id), let nextNext = tokenizer.nextNext {
            if isPostNoun(node: nextNext) {
                tokenizer.nodes[0].features[24] = "1"
            } else {
                tokenizer.nodes[0].features[24] = "0"
            }
        }
    }

}

struct PronunciationResolver: ExceptionResolver {

    func resolve(tokenizer: MeCabTokenizer) {
        // いう(ユー) → いう(イウ)
        if tokenizer.next.id == "1571" {
            if tokenizer.next.surface.katakana == "イウ" {
                tokenizer.nodes[0].features[10] = "イウ"
                tokenizer.nodes[0].features[12] = "イウ"
                tokenizer.nodes[0].features[22] = "イウ"
                tokenizer.nodes[0].features[23] = "イウ"
            }
        }
    }

}

struct SentenceEnderResolver: ExceptionResolver {

    func resolve(tokenizer: MeCabTokenizer) {
        if tokenizer.next.partOfSpeech == "補助記号" && tokenizer.next.partOfSpeechSubType == "句点" {
            tokenizer.nodes.insert(Node(surface: "*", features: Array(repeating: "*", count: 30), type: .endOfSentence), at: 1)
            tokenizer.nodes.insert(Node(surface: "*", features: Array(repeating: "*", count: 30), type: .beginOfSentence), at: 2)
        }
    }

}

public class MeCabTokenizer {

    enum Error: Swift.Error {
        case expectFailed
        case ranOutOfInput
    }

    var nodes: [Node]

    let resolvers: [ExceptionResolver] = [
        DeAruExceptionResolver(),
        PitchAccentResolver(),
        PronunciationResolver(),
        SentenceEnderResolver()
    ]

    public init(nodes: [Node]) {
        self.nodes = nodes
    }

    @discardableResult
    func consume() -> Node {
        return nodes.removeFirst()
    }

    func consume(times: Int) throws -> [Node] {
        guard nodes.count >= times else {
            throw Error.ranOutOfInput
        }

        var result = [Node]()
        while result.count != times {
            result.append(consume())
        }
        return result
    }

    @discardableResult
    func consume(expect: (Node) -> Bool) throws -> Node {
        guard !reachedEnd && expect(next) else {
            throw Error.expectFailed
        }
        return consume()
    }

    func lookAheadFix() {
        resolvers.forEach({ $0.resolve(tokenizer: self) })
    }

    var next: Node {
        nodes[0]
    }

    var nextNext: Node? {
        nodes.count > 1 ? nodes[1] : nil
    }

    var reachedEnd: Bool {
        nodes.isEmpty
    }

}

extension String {

    var katakana: String {
        self.applyingTransform(.hiraganaToKatakana, reverse: false) ?? self
    }

    var hiragana: String {
        self.applyingTransform(.hiraganaToKatakana, reverse: true) ?? self
    }

}

struct Sentence: Content {

    static func parseMultiple(db: Database, tokenizer: MeCabTokenizer) throws -> [Sentence] {
        var sentences = [Sentence]()
        while !tokenizer.reachedEnd {
            let sentence = try parse(db: db, tokenizer: tokenizer)
            sentences.append(sentence)
        }
        return sentences.filter { !$0.accentPhrases.isEmpty }
    }

    static func parse(db: Database, tokenizer: MeCabTokenizer) throws -> Sentence {
        try tokenizer.consume(expect: { $0.type == .beginOfSentence })
        let accentPhrases = try AccentPhrase.parseMultiple(db: db, tokenizer: tokenizer, until: { $0.type == .endOfSentence })
        try tokenizer.consume(expect: { $0.type == .endOfSentence })
        return .init(accentPhrases: accentPhrases)
    }

    var accentPhrases: [AccentPhrase]

}

struct AccentPhrase: Content {

    static func parseMultiple(db: Database, tokenizer: MeCabTokenizer, until: @escaping (Node) -> Bool) throws -> [AccentPhrase] {
        var words = [AccentPhrase]()
        while !tokenizer.reachedEnd && !until(tokenizer.next) {
            let word = try parse(db: db, tokenizer: tokenizer)
            words.append(word)
        }
        return words
    }

    static func parse(db: Database, tokenizer: MeCabTokenizer) throws -> AccentPhrase {
        let morphemes = try Morpheme.parseMultiple(db: db, tokenizer: tokenizer)

        // TODO: isBasic: node.isBasic
        let startComplex = Array(morphemes.prefix(while: { !$0.isBasic }))
        let endBasic = Array(morphemes.suffix(from: startComplex.count))

        if startComplex.count > 0 && endBasic.count > 0 && endBasic.allSatisfy({ $0.isBasic }) {
            let word = AccentPhraseComponent.parse(from: startComplex)
            var components: [AccentPhraseComponent] = endBasic.map { AccentPhraseComponent.parse(from: [$0]) }
            components.insert(word, at: 0)
            return AccentPhrase(components: components, pitchAccent: PitchAccent.pitchAccent(for: morphemes), surface: components.map { $0.surface }.joined(), pronunciation: components.map { $0.pronunciation }.joined(), isBasic: false)
        }

        let word = AccentPhraseComponent.parse(from: morphemes)
        return AccentPhrase(components: [word], pitchAccent: word.pitchAccents[0], surface: word.surface, pronunciation: word.pronunciation, isBasic: word.isBasic)
    }

    var components: [AccentPhraseComponent]
    let pitchAccent: PitchAccent
    let surface: String
    let pronunciation: String
    let isBasic: Bool

}

struct AccentPhraseComponent: Content {

    static func parse(from morphemes: [Morpheme]) -> AccentPhraseComponent {
        let surface = morphemes.map { $0.surface }.joined()
        let original = morphemes.map { $0.original }.joined()
        let pronunciation = morphemes.map { $0.pronunciation }.joined()
        let ruby = morphemes.map { $0.ruby }.joined()

        let frequencyItem = [
            DictionaryManager.shared.frequencyList[surface],
            DictionaryManager.shared.frequencyList[pronunciation],
            DictionaryManager.shared.frequencyList[pronunciation.hiragana],
            DictionaryManager.shared.frequencyList[original]
        ].compactMap { $0 }.min()

        return AccentPhraseComponent(
            morphemes: morphemes,
            pitchAccents: [PitchAccent.pitchAccent(for: morphemes)],
            surface: surface,
            original: original,
            pronunciation: pronunciation,
            ruby: ruby,
            frequency: frequencyItem?.frequency ?? .unknown,
            isCompound: morphemes.count > 1,
            isBasic: morphemes.count == 1 && morphemes[0].isBasic
        )
    }

    let morphemes: [Morpheme]
    let pitchAccents: [PitchAccent]
    let surface: String
    let original: String
    let pronunciation: String
    let ruby: String
    let frequency: Frequency
    let isCompound: Bool
    let isBasic: Bool

    var headwords = [Headword]()
    var listWords = [ListWord]()

    func shouldIgnore(for user: User) -> Bool {
        isBasic || user.ignoreWords.contains(original)
    }

}

struct Morpheme: Content {

    static func parseMultiple(db: Database, tokenizer: MeCabTokenizer, morphemes: [Morpheme] = []) throws -> [Morpheme] {
        if tokenizer.reachedEnd || tokenizer.next.isBosEos {
            return morphemes
        }

        tokenizer.lookAheadFix()

        let nextMorpheme = parse(from: tokenizer.next)

        if morphemes.isEmpty {
            return try parseMultiple(db: db, tokenizer: tokenizer, morphemes: [Morpheme.parse(from: tokenizer.consume())])
        }

        let lastMorpheme = morphemes.last!

        if lastMorpheme.pronunciation.isEmpty {
            return morphemes
        }

        if ["接尾辞"].contains(nextMorpheme.partOfSpeech) || ["接続助詞"].contains(nextMorpheme.partOfSpeechSubType) || ["接頭辞"].contains(lastMorpheme.partOfSpeech) {
            return try parseMultiple(db: db, tokenizer: tokenizer, morphemes: morphemes + [Morpheme.parse(from: tokenizer.consume())])
        }

        if nextMorpheme.pitchAccentCompoundKinds.contains(where: { $0.canBeCombined(withPrevPartOfSpeech: lastMorpheme.partOfSpeech) }) || lastMorpheme.pitchAccentCompoundKinds.contains(where: { $0.canBeCombined(withNextPartOfSpeech: nextMorpheme.partOfSpeech) }) || (lastMorpheme.features[1] == "数詞" && (nextMorpheme.features.contains("助数詞可能") || nextMorpheme.features[1] == "数詞")) {
            return try parseMultiple(db: db, tokenizer: tokenizer, morphemes: morphemes + [Morpheme.parse(from: tokenizer.consume())])
        }

        if (!["名詞"].contains(nextMorpheme.partOfSpeech) && !["名詞"].contains(morphemes.last!.partOfSpeech)) || ["連体詞"].contains(morphemes.last!.partOfSpeech) {
            return morphemes
        }

        var possibleNodes = morphemes
        var longestMatchingNodes = morphemes
        var index = 0
        while index < tokenizer.nodes.count && index < 10 && !tokenizer.nodes[index].isBosEos {
            let addedMorpheme = Morpheme.parse(from: tokenizer.nodes[index])
            possibleNodes.append(addedMorpheme)
            let original = possibleNodes.map { $0.original }.joined()
            let surface = possibleNodes.map { $0.surface }.joined()
            if (!addedMorpheme.surface.isEmpty && DictionaryManager.shared.words.contains(surface)) || (!addedMorpheme.original.isEmpty && DictionaryManager.shared.words.contains(original)) {
                longestMatchingNodes = possibleNodes
            }
            index += 1
        }

        let foundMorphemes = try tokenizer.consume(times: longestMatchingNodes.count - morphemes.count).map { Morpheme.parse(from: $0) }
        return morphemes + foundMorphemes
    }

    static func parse(from node: Node) -> Morpheme {
        let pitchCompounds = (node.features.count > 25 ? node.features[25] : "")
        let kinds = pitchCompounds.match("(\\p{Han}+%)?[A-Z][0-9]+(@\\-?[0-9]+)?(,\\-?[0-9]+)*").map { $0[0] }

        return .init(
            id: node.id,
            pitchAccents: node.pitchAccents,
            pitchAccentCompoundKinds: kinds.map { PitchAccentConnectionKind(string: String($0)) },
            pitchAccentModificationKind: PitchAccentModificationKind(string: (node.features.count > 26 ? node.features[26] : "")),
            surface: node.surface,
            original: node.original,
            partOfSpeech: node.partOfSpeech,
            partOfSpeechSubType: node.partOfSpeechSubType,
            pronunciation: node.surfacePronunciation == "*" ? node.surface : node.surfacePronunciation,
            ruby: node.ruby,
            isBasic: node.isBasic,
            features: node.features
        )
    }

    let id: String
    let pitchAccents: [PitchAccent]
    let pitchAccentCompoundKinds: [PitchAccentConnectionKind]
    let pitchAccentModificationKind: PitchAccentModificationKind
    let surface: String
    let original: String
    let partOfSpeech: String
    let partOfSpeechSubType: String
    let pronunciation: String
    let ruby: String
    let isBasic: Bool
    let features: [String]
    var headwords: [Headword] = []
    var listWords: [ListWord] = []

}

indirect enum PitchAccentConnectionKind: Content {

    case unknown
    case secondHalfAccentOverride
    case secondHalfHeadMora
    case firstHalfLastMora
    case heiban
    case firstHalfAccent
    case particleOriginal
    case particleSecondHalfAccentRecessive(m: Int)
    case particleSecondHalfAccentShifting(m: Int)
    case particleSecondHalfAccentDominant(m: Int)
    case particleSecondHalfAccentDominantMultiple(m: Int, l: Int)
    case prefixHeibanHeadElseSecondHalf
    case prefixFlatHead
    case prefixDominant
    case restricted(partOfSpeech: String, kind: PitchAccentConnectionKind)

    init(string: String) {
        switch string {
        case "*":
            self = .unknown
        case "C1":
            self = .secondHalfAccentOverride
        case "C2":
            self = .secondHalfHeadMora
        case "C3":
            self = .firstHalfLastMora
        case "C4":
            self = .heiban
        case "C5":
            self = .firstHalfAccent
        case "F1":
            self = .particleOriginal
        case "P2":
            self = .prefixHeibanHeadElseSecondHalf
        case "P4":
            self = .prefixFlatHead
        case "P13":
            self = .prefixDominant
        default:
            let parts = string.split(separator: "%")
            let atParts = string.split(separator: "@")
            if parts.count == 2 {
                self = .restricted(partOfSpeech: String(parts[0]), kind: .init(string: String(parts[1])))
            } else if atParts.count == 2 {
                switch atParts[0] {
                case "F2":
                    self = .particleSecondHalfAccentRecessive(m: Int(String(atParts[1].split(separator: ",")[0]))!)
                case "F3":
                    self = .particleSecondHalfAccentShifting(m: Int(String(atParts[1].split(separator: ",")[0]))!)
                case "F4":
                    self = .particleSecondHalfAccentDominant(m: Int(String(atParts[1].split(separator: ",")[0]))!)
                case "F6":
                    let numSplits = atParts[1].split(separator: ",")
                    let m = Int(String(numSplits[0]))!
                    var l = m
                    if numSplits.count > 1 {
                        l = Int(String(numSplits[1]))!
                    }
                    self = .particleSecondHalfAccentDominantMultiple(m: m, l: l)
                default:
                    print("unknown pitch kind: \(string)")
                    self = .unknown
                }
            } else {
                print("unknown pitch kind: \(string)")
                self = .unknown
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self = .init(string: string)
    }

    var stringValue: String {
        switch self {
        case .unknown:
            return "*"
        case .secondHalfAccentOverride:
            return "C1"
        case .secondHalfHeadMora:
            return "C2"
        case .firstHalfLastMora:
            return "C3"
        case .heiban:
            return "C4"
        case .firstHalfAccent:
            return "C5"
        case .particleOriginal:
            return "F1"
        case .prefixHeibanHeadElseSecondHalf:
            return "P2"
        case .prefixFlatHead:
            return "P4"
        case .prefixDominant:
            return "P13"
        case .restricted(let partOfSpeech, let kind):
            return "\(partOfSpeech)%\(kind)"
        case .particleSecondHalfAccentRecessive(let m):
            return "F2@\(m)"
        case .particleSecondHalfAccentShifting(let m):
            return "F3@\(m)"
        case .particleSecondHalfAccentDominant(let m):
            return "F4@\(m)"
        case .particleSecondHalfAccentDominantMultiple(let m, let l):
            return "F6@\(m),\(l)"
        }
    }

    func canBeCombined(withPrevPartOfSpeech partOfSpeech: String) -> Bool {
        switch self {
        case .restricted(let pos, let kind):
            return pos == partOfSpeech && kind.canBeCombined(withPrevPartOfSpeech: partOfSpeech)
        case .particleOriginal, .particleSecondHalfAccentRecessive, .particleSecondHalfAccentDominant, .particleSecondHalfAccentShifting, .particleSecondHalfAccentDominantMultiple:
            return true
        default:
            return false
        }
    }

    func canBeCombined(withNextPartOfSpeech partOfSpeech: String) -> Bool {
        switch self {
        case .restricted(let pos, let kind):
            return pos == partOfSpeech && kind.canBeCombined(withNextPartOfSpeech: partOfSpeech)
        case .prefixHeibanHeadElseSecondHalf, .prefixDominant, .prefixFlatHead:
            return true
        default:
            return false
        }
    }

    func canBeApplied(toPartOfSpeech partOfSpeech: String) -> Bool {
        switch self {
        case .restricted(let pos, _):
            return pos == partOfSpeech
        default:
            return true
        }
    }

    var simple: PitchAccentConnectionKind {
        switch self {
        case .restricted(_, let kind):
            return kind
        default:
            return self
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }

}

indirect enum PitchAccentModificationKind: Content {

    case unknown
    case dominant(m: Int)
    case recessive(m: Int)

    init(string: String) {
        switch string {
        case "*":
            self = .unknown
        default:
            let parts = string.split(separator: "%")
            let atParts = string.split(separator: "@")
            if parts.count == 2 {
                print("unknown pitch kind: \(string)")
                self = .unknown
            } else if atParts.count == 2 {
                switch atParts[0] {
                case "M1":
                    self = .dominant(m: Int(String(atParts[1].split(separator: ",")[0]))!)
                case "M2":
                    self = .recessive(m: Int(String(atParts[1].split(separator: ",")[0]))!)
                default:
                    print("unknown pitch kind: \(string)")
                    self = .unknown
                }
            } else {
                print("unknown pitch kind: \(string)")
                self = .unknown
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self = .init(string: string)
    }

    var stringValue: String {
        switch self {
        case .unknown:
            return "*"
        case .dominant(let m):
            return "M1@\(m)"
        case .recessive(let m):
            return "M2@\(m)"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }

}
