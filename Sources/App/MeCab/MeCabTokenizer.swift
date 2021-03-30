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

        // 何
        if tokenizer.next.id == "27920" {
            tokenizer.nodes[0].features[24] = "1"
        }

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

        // 私 → わたし
        if tokenizer.next.id == "41274" {
            tokenizer.nodes[0].features[6] = "ワタシ"
            tokenizer.nodes[0].features[9] = "ワタシ"
            tokenizer.nodes[0].features[11] = "ワタシ"
            tokenizer.nodes[0].features[21] = "ワタシ"
            tokenizer.nodes[0].features[22] = "ワタシ"
            tokenizer.nodes[0].features[23] = "ワタシ"
        }

        // は → ワ
        if tokenizer.next.id == "29321" {
            tokenizer.nodes[0].features[6] = "ワ"
            tokenizer.nodes[0].features[20] = "ワ"
            tokenizer.nodes[0].features[21] = "ワ"
            tokenizer.nodes[0].features[22] = "ワ"
            tokenizer.nodes[0].features[23] = "ワ"
            tokenizer.nodes[0].alwaysHideFurigana = true
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
        PronunciationResolver()
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

struct SimpleSentence: Content {
    var accentPhrases: [SimpleAccentPhrase]
}

struct Sentence {

    static func parseMultiple(tokenizer: MeCabTokenizer) throws -> [Sentence] {
        return tokenizer.nodes
            .filter { !$0.isBosEos }
            .splitKeepingSeparator(whereSeparator: {
                $0.partOfSpeech == "補助記号" && ["句点", "括弧閉"].contains($0.partOfSpeechSubType)
            })
            .concurrentMap { nodes -> [Sentence] in
                var sentences = [Sentence]()
                let tokenizer = MeCabTokenizer(nodes: Array(nodes))
                while !tokenizer.reachedEnd {
                    if let sentence = try? parse(tokenizer: tokenizer) {
                        sentences.append(sentence)
                    }
                }
                return sentences
            }
            .flatMap { $0 }
            .filter { !$0.accentPhrases.isEmpty }
    }

    static func parse(tokenizer: MeCabTokenizer) throws -> Sentence {
        let accentPhrases = try AccentPhrase.parseMultiple(tokenizer: tokenizer, until: { $0.type == .endOfSentence })
        return .init(accentPhrases: accentPhrases)
    }

    var accentPhrases: [AccentPhrase]

    var simplified: SimpleSentence {
        .init(accentPhrases: accentPhrases.map { SimpleAccentPhrase(
            components: $0.components.map {
                SimpleAccentPhraseComponent(
                    pitchAccents: $0.pitchAccents,
                    surface: $0.surface,
                    original: $0.original,
                    pronunciation: $0.pronunciation,
                    ruby: $0.ruby,
                    frequency: $0.frequency,
                    frequencySurface: $0.frequencySurface,
                    isCompound: $0.isCompound,
                    isBasic: $0.isBasic
                )
            },
            pitchAccent: $0.pitchAccent,
            surface: $0.surface,
            pronunciation: $0.pronunciation,
            isBasic: $0.isBasic
        )})
    }

}

struct SimpleAccentPhrase: Content {

    var components: [SimpleAccentPhraseComponent]
    let pitchAccent: PitchAccent
    let surface: String
    let pronunciation: String
    let isBasic: Bool

}

struct AccentPhrase {

    static func parseMultiple(tokenizer: MeCabTokenizer, until: @escaping (Node) -> Bool) throws -> [AccentPhrase] {
        var words = [AccentPhrase]()
        while !tokenizer.reachedEnd && !until(tokenizer.next) {
            let word = try parse(tokenizer: tokenizer)
            words.append(word)
        }
        return words
    }

    static func parse(tokenizer: MeCabTokenizer) throws -> AccentPhrase {
        let morphemes = try Morpheme.parseMultiple(tokenizer: tokenizer)

        // TODO: isBasic: node.isBasic
        let startComplex = Array(morphemes.prefix(while: { !$0.isBasic }))
        let endBasic = Array(morphemes.suffix(from: startComplex.count))

        if startComplex.count > 0 && endBasic.count > 0 && endBasic.allSatisfy({ $0.isBasic }) {
            let word = AccentPhraseComponent.parse(from: startComplex)
            var components: [AccentPhraseComponent] = endBasic.map { AccentPhraseComponent.parse(from: [$0]) }
            components.insert(word, at: 0)
            var pitchAccent = PitchAccent.pitchAccent(for: morphemes)
            let pronunciation = components.map { $0.pronunciation }.joined()
            if pitchAccent.mora > 1 && pronunciation.isSpecialMora(at: pitchAccent.mora - 1) {
                pitchAccent = PitchAccent(mora: pitchAccent.mora - 1, length: pronunciation.moraCount)
            }
            return AccentPhrase(components: components, pitchAccent: pitchAccent, surface: components.map { $0.surface }.joined(), pronunciation: pronunciation, isBasic: false)
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

struct SimpleAccentPhraseComponent: Content {

    let pitchAccents: [PitchAccent]
    let surface: String
    let original: String
    let pronunciation: String
    let ruby: String
    let frequency: Frequency
    let frequencySurface: String?
    let isCompound: Bool
    let isBasic: Bool
    var status: Word.Status = .unknown

}

struct AccentPhraseComponent {

    static func parse(from morphemes: [Morpheme]) -> AccentPhraseComponent {
        let surface = morphemes.map { $0.surface }.joined()
        let original = morphemes.map { $0.original }.joined()
        let pronunciation = morphemes.map { $0.pronunciation }.joined()
        let surfacePronunciation = morphemes.map { $0.surfacePronunciation }.joined()
        let ruby = morphemes.map { $0.ruby }.joined()

        let frequencyItem = [
            DictionaryManager.shared.frequencyList[surface],
            DictionaryManager.shared.frequencyList[surfacePronunciation],
            DictionaryManager.shared.frequencyList[surfacePronunciation.hiragana],
            DictionaryManager.shared.frequencyList[original]
        ].compactMap { $0 }.min()

        var pitchAccent = PitchAccent.pitchAccent(for: morphemes)
        if pitchAccent.mora > 1 && pronunciation.isSpecialMora(at: pitchAccent.mora - 1) {
            pitchAccent = PitchAccent(mora: pitchAccent.mora - 1, length: pronunciation.moraCount)
        }

        return AccentPhraseComponent(
            morphemes: morphemes,
            pitchAccents: [pitchAccent],
            surface: surface,
            original: original,
            pronunciation: pronunciation,
            ruby: ruby,

            frequency: frequencyItem?.frequency ?? .unknown,
            frequencySurface: frequencyItem?.word,
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
    var frequencySurface: String?
    let isCompound: Bool
    let isBasic: Bool

    var status: Word.Status = .unknown
    var headwords = [Headword]()
    var listWords = [ListWord]()

    func shouldIgnore(for user: User) -> Bool {
        isBasic
    }

}

struct Morpheme: Content {

    static func parseMultiple(tokenizer: MeCabTokenizer, morphemes: [Morpheme] = []) throws -> [Morpheme] {
        if tokenizer.reachedEnd || tokenizer.next.isBosEos {
            return morphemes
        }

        tokenizer.lookAheadFix()

        if morphemes.isEmpty {
            return try parseMultiple(tokenizer: tokenizer, morphemes: [parse(from: tokenizer.consume())])
        }

        let lastMorpheme = morphemes.last!

        if lastMorpheme.surfacePronunciation.isEmpty {
            return morphemes
        }

        if ["接尾辞", "助動詞", "助詞"].contains(tokenizer.next.partOfSpeech) || ["接続助詞", "副助詞"].contains(tokenizer.next.partOfSpeechSubType) || ["接頭辞"].contains(lastMorpheme.partOfSpeech) {
            return try parseMultiple(tokenizer: tokenizer, morphemes: morphemes + [parse(from: tokenizer.consume())])
        }

        if tokenizer.next.pitchAccentCompoundKinds.contains(where: { $0.canBeCombined(withPrevPartOfSpeech: lastMorpheme.partOfSpeech) }) || lastMorpheme.pitchAccentCompoundKinds.contains(where: { $0.canBeCombined(withNextPartOfSpeech: tokenizer.next.partOfSpeech) }) || (lastMorpheme.features[1] == "数詞" && (tokenizer.next.features.contains("助数詞可能") || tokenizer.next.features[1] == "数詞")) {
            return try parseMultiple(tokenizer: tokenizer, morphemes: morphemes + [parse(from: tokenizer.consume())])
        }

        if (!["名詞"].contains(tokenizer.next.partOfSpeech) && !["名詞"].contains(lastMorpheme.partOfSpeech)) || ["連体詞"].contains(lastMorpheme.partOfSpeech) {
            return morphemes
        }

        var possibleNodes = [Node]()
        var longestMatchingNodes = [Node]()
        var index = 0
        while index < tokenizer.nodes.count && index < 10 && !tokenizer.nodes[index].isBosEos {
            let addedNode = tokenizer.nodes[index]
            possibleNodes.append(addedNode)
            let original = morphemes.map { $0.original }.joined() + possibleNodes.map { $0.original }.joined()
            let surface = morphemes.map { $0.surface }.joined() + possibleNodes.map { $0.surface }.joined()
            if (!addedNode.surface.isEmpty && DictionaryManager.shared.words.contains(surface)) || (!addedNode.original.isEmpty && DictionaryManager.shared.words.contains(original)) {
                longestMatchingNodes = possibleNodes
            }
            index += 1
        }

        let foundMorphemes = try tokenizer.consume(times: longestMatchingNodes.count).map { Morpheme.parse(from: $0) }
        if foundMorphemes.isEmpty {
            return morphemes
        }
        return try parseMultiple(tokenizer: tokenizer, morphemes: morphemes + foundMorphemes)
    }

    static func parse(from node: Node) -> Morpheme {
        .init(
            id: node.id,
            pitchAccents: node.pitchAccents,
            pitchAccentCompoundKinds: node.pitchAccentCompoundKinds,
            pitchAccentModificationKind: node.pitchAccentModificationKind,
            surface: node.surface,
            original: node.original,
            partOfSpeech: node.partOfSpeech,
            partOfSpeechSubType: node.partOfSpeechSubType,
            pronunciation: node.pronunciation == "*" ? node.surface : node.pronunciation,
            surfacePronunciation: node.surfacePronunciation == "*" ? node.surface : node.surfacePronunciation,
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
    let surfacePronunciation: String
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
    case prefixHeiban
    case prefixHeibanOdakaFlatElseSame
    case prefixHeibanHeadElseSame
    case prefixHeibanOdakaFlatElsePrefix
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
        case "P1":
            self = .prefixHeibanOdakaFlatElseSame
        case "P2":
            self = .prefixHeibanHeadElseSame
        case "P4":
            self = .prefixHeibanOdakaFlatElsePrefix
        case "P6":
            self = .prefixHeiban
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
                    print(" v \(string)")
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
        case .prefixHeibanOdakaFlatElseSame:
            return "P1"
        case .prefixHeibanHeadElseSame:
            return "P2"
        case .prefixHeibanOdakaFlatElsePrefix:
            return "P4"
        case .prefixHeiban:
            return "P6"
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
        case .prefixHeiban, .prefixHeibanOdakaFlatElseSame, .prefixHeibanHeadElseSame, .prefixDominant, .prefixHeibanOdakaFlatElsePrefix:
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
    case heibanHeadSameElseAccent(m: Int)

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
                case "M4":
                    self = .heibanHeadSameElseAccent(m: Int(String(atParts[1].split(separator: ",")[0]))!)
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
        case .heibanHeadSameElseAccent(let m):
            return "M4@\(m)"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }

}
