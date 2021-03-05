import Fluent
import Foundation
import MeCab
import Vapor

extension String {

    static let smallRowKanaExcludingSokuon = CharacterSet(charactersIn: "ァィゥェォヵㇰヶㇱㇲㇳㇴㇵㇶㇷㇷ゚ㇸㇹㇺャュョㇻㇼㇽㇾㇿヮぁぃぅぇぉゃゅょゎ")

    var moraCount: Int {
        filter { !Self.smallRowKanaExcludingSokuon.contains($0.unicodeScalars.first!) }.count
    }

    func match(_ regex: String) -> [[String]] {
        let nsString = self as NSString
        return (try? NSRegularExpression(pattern: regex, options: []))?.matches(in: self, options: [], range: NSMakeRange(0, count)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : nsString.substring(with: match.range(at: $0)) }
        } ?? []
    }

}


extension Node {

    var original: String {
        (features.count > 7 ? features[7] : "").split(separator: "-").first.flatMap { String($0) } ?? ""
    }

    var partOfSpeech: String {
        features[0]
    }

    var partOfSpeechSubType: String {
        features[1]
    }

    var id: String {
        features.last ?? ""
    }

    var pronunciation: String {
        (features.count > 6 ? features[6] : "").split(separator: "-").first.flatMap { String($0) } ?? ""
    }

    var surfacePronunciation: String {
        ((features.count > 22 ? features[22] : "").split(separator: "-").first.flatMap { String($0) } ?? "")
    }

    var ruby: String {
        //  使う → 使ウ
        // 入り込む → 入リ込ム
        let katakanaSurface = surface.katakana
        guard katakanaSurface != surfacePronunciation else {
            return surface
        }

        //  使ウ → (.+)ウ
        // 入リ込ム → (.+)リ(.+)ム
        let regexString = katakanaSurface.replacingOccurrences(of: "\\p{Han}+", with: "(.+)", options: [.regularExpression])

        // [ツカ]
        // [ハイ, コ]
        var captures = surfacePronunciation.match(regexString).first?.suffix(from: 1) ?? []
        guard !captures.isEmpty else {
            return "<ruby>\(surface)<rt>\(surfacePronunciation)</rt></ruby>"
        }

        var result = surface
        var startIndex: String.Index? = nil
        while let range = result.range(of: "\\p{Han}+", options: .regularExpression, range: startIndex.flatMap { ($0..<result.endIndex) }) {
            let kanji = result[range]
            guard !captures.isEmpty else {
                return "<ruby>\(surface)<rt>\(surfacePronunciation)</rt></ruby>"
            }
            let kana = captures.removeFirst().hiragana
            result.replaceSubrange(range, with: "<ruby>\(kanji)<rt>\(kana)</rt></ruby>")
            startIndex = result.lastIndex(of: ">")
        }

        return result
    }

    var pitchAccentIntegers: [Int] {
        let feature24 = (features.count > 24 ? features[24] : "").split(separator: ",")
        return feature24.compactMap { Int($0) }
    }

    var pitchAccents: [PitchAccent] {
        guard !pitchAccentIntegers.isEmpty else {
            return [.init(mora: -1, length: 0)]
        }
        return pitchAccentIntegers.map { i in
            return PitchAccent(mora: i, length: pronunciation.moraCount, isTwoKind: partOfSpeech == "動詞" || partOfSpeech == "形容詞")
        }
    }

    var isGenerallyIgnored: Bool {
        ["助詞", "補助記号", "助動詞", "補助記号", "空白"].contains(partOfSpeech)
    }

    func shouldIgnore(for user: User) -> Bool {
        isBasic || user.ignoreWords.contains(original)
    }

    var isBasic: Bool {
        isBosEos || isGenerallyIgnored
    }

    var shouldDisplay: Bool {
        !isBosEos
    }

}

struct PitchAccent: Content, Codable {

    static func pitchAccent(for morphemes: [Morpheme]) -> PitchAccent {
        if morphemes.count == 1 {
            return morphemes[0].pitchAccents[0]
        }

        var remaining = morphemes
        var morpheme = remaining.removeFirst()
        var buildUpWord = morpheme.pronunciation
        var accent = morpheme.pitchAccents[0]

        while !remaining.isEmpty {
            // Handle prefixes
            let nextMorpheme = remaining.removeFirst()
            var kind = morpheme.pitchAccentCompoundKinds.first(where: { $0.canBeApplied(toPartOfSpeech: nextMorpheme.partOfSpeech)})?.simple
            let secondHalfAccent = nextMorpheme.pitchAccents[0]
            var wasPrefix = false
            switch kind {
            case .prefixHeibanHeadElseSecondHalf:
                wasPrefix = true
                if secondHalfAccent.descriptive == .heiban || secondHalfAccent.descriptive == .odaka {
                    let i = buildUpWord.moraCount + 1
                    buildUpWord += nextMorpheme.pronunciation
                    accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
                } else if secondHalfAccent.descriptive != .unknown {
                    let i = buildUpWord.moraCount + secondHalfAccent.mora
                    buildUpWord += nextMorpheme.pronunciation
                    accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
                } else {
                    return PitchAccent(mora: -1, length: 0)
                }
            case .prefixDominant:
                wasPrefix = true
                buildUpWord += nextMorpheme.pronunciation
                accent = PitchAccent(mora: accent.mora, length: buildUpWord.moraCount)
                continue
            case .prefixFlatHead:
                wasPrefix = true
                if secondHalfAccent.descriptive == .heiban || secondHalfAccent.descriptive == .odaka {
                    let i = buildUpWord.moraCount + 1
                    buildUpWord += nextMorpheme.pronunciation
                    accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
                } else if secondHalfAccent.descriptive != .unknown {
                    buildUpWord += nextMorpheme.pronunciation
                    accent = PitchAccent(mora: accent.mora, length: buildUpWord.moraCount)
                } else {
                    return PitchAccent(mora: -1, length: 0)
                }
            default:
                break
            }

            // Handle suffixes
            if !wasPrefix && accent.descriptive == .unknown {
                return accent
            }
            morpheme = nextMorpheme
            if wasPrefix {
                continue
            }
            kind = morpheme.pitchAccentCompoundKinds.first(where: { $0.canBeApplied(toPartOfSpeech: morphemes[0].partOfSpeech)})?.simple
            switch kind {
            case .secondHalfAccentOverride:
                let i = buildUpWord.moraCount + secondHalfAccent.mora
                buildUpWord += morpheme.pronunciation
                accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
            case .secondHalfHeadMora:
                let i = buildUpWord.moraCount + 1
                buildUpWord += morpheme.pronunciation
                accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
            case .firstHalfLastMora:
                let i = buildUpWord.moraCount
                buildUpWord += morpheme.pronunciation
                accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
            case .heiban:
                buildUpWord += morpheme.pronunciation
                accent = PitchAccent(mora: 0, length: buildUpWord.moraCount)
            case .firstHalfAccent, .particleOriginal:
                buildUpWord += morpheme.pronunciation
                accent = PitchAccent(mora: accent.mora, length: buildUpWord.moraCount)
            case .particleSecondHalfAccentShifting(let m):
                if accent.descriptive == .heiban {
                    buildUpWord += morpheme.pronunciation
                    accent = PitchAccent(mora: accent.mora, length: buildUpWord.moraCount)
                } else {
                    let i = buildUpWord.moraCount + m
                    buildUpWord += morpheme.pronunciation
                    accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
                }
            case .particleSecondHalfAccentRecessive(let m):
                if accent.descriptive == .heiban {
                    let i = buildUpWord.moraCount + m
                    buildUpWord += morpheme.pronunciation
                    accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
                } else {
                    buildUpWord += morpheme.pronunciation
                    accent = PitchAccent(mora: accent.mora, length: buildUpWord.moraCount)
                }
            case .particleSecondHalfAccentDominant(let m):
                let i = buildUpWord.moraCount + m
                buildUpWord += morpheme.pronunciation
                accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
            case .particleSecondHalfAccentDominantMultiple(let m, let l):
                if accent.descriptive == .heiban {
                    let i = buildUpWord.moraCount + m
                    buildUpWord += morpheme.pronunciation
                    accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
                } else {
                    let i = buildUpWord.moraCount + l
                    buildUpWord += morpheme.pronunciation
                    accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
                }
            default:
                return PitchAccent(mora: -1, length: 0)
            }

            switch morpheme.pitchAccentModificationKind {
            case .dominant(m: let m):
                accent = PitchAccent(mora: buildUpWord.count - m, length: buildUpWord.moraCount)
            case .recessive(m: let m):
                if accent.descriptive == .heiban {
                    accent = PitchAccent(mora: buildUpWord.count - m, length: buildUpWord.moraCount)
                }
            default:
                break
            }
        }

        return accent
    }

    let mora: Int
    let descriptive: DescriptivePitchAccent

    init(mora i: Int, length c: Int, isTwoKind: Bool = false) {
        mora = i

        if i == -1 {
            descriptive = .unknown
        } else if i == .zero {
            descriptive = .heiban
        } else if isTwoKind {
            descriptive = .kihuku
        } else if i == c {
            descriptive = .odaka
        } else if i == 1 {
            descriptive = .atamadaka
        } else {
            descriptive = .nakadaka
        }
    }
}

enum DescriptivePitchAccent: String, Content {

    case heiban
    case kihuku
    case odaka
    case nakadaka
    case atamadaka
    case unknown

}

struct ParseResult: Content {

    let surface: String
    let original: String
    let ruby: String
    let shouldDisplay: Bool
    let isBasic: Bool
    let frequency: Frequency
    let pitchAccent: PitchAccent
    let headwords: [Headword]
    let listWords: [ListWord]

}

struct Offset {
    let accentPhraseComponent: AccentPhraseComponent
    let accentPhraseComponentOffset: Int
    let accentPhraseOffset: Int
    let sentenceOffset: Int
}

class ListsController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let dictionary = routes.grouped("lists")
            .grouped(User.guardMiddleware())

        let word = dictionary.grouped("word")
        let words = dictionary.grouped("words")
        let sentence = dictionary.grouped("sentence")

        word.get("first") { (req: Request) -> EventLoopFuture<ListWord> in
            let user = try req.auth.require(User.self)
            let isLookup = (try? req.query.get(Bool.self, at: "isLookup")) ?? false
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            return user
                .$listWords
                .query(on: req.db)
                .filter(\.$value =~ q)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMap { word in
                    if isLookup {
                        word.lookups += 1
                        return word.save(on: req.db)
                            .map { word }
                    } else {
                        return req.eventLoop.future(word)
                    }
                }
        }

        word.post() { (req: Request) -> EventLoopFuture<ListWord> in
            let user = try req.auth.require(User.self)

            try ListWord.Create.validate(content: req)
            let object = try req.content.decode(ListWord.Create.self)
            let listWord = ListWord(owner: user, value: object.value, note: object.note ?? "", tags: object.tags ?? [])

            return listWord
                .save(on: req.db)
                .map { listWord }
        }

        word.delete(":wordID") { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            guard let wordID = req.parameters.get("wordID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user
                .$listWords
                .query(on: req.db)
                .filter(\.$id == wordID)
                .delete()
                .map {
                    Response(status: .ok)
                }
        }

        word.put(":wordID") { (req: Request) -> EventLoopFuture<ListWord> in
            let user = try req.auth.require(User.self)
            guard let wordID = req.parameters.get("wordID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try ListWord.Put.validate(content: req)
            let object = try req.content.decode(ListWord.Put.self)

            return user
                .$listWords
                .query(on: req.db)
                .filter(\.$id == wordID)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMap { word in
                    word.value = object.value
                    word.note = object.note
                    word.tags = object.tags
                    return word.save(on: req.db)
                        .map {
                            word
                        }
                }
        }

        words.get() { (req: Request) -> EventLoopFuture<[ListWord]> in
            let user = try req.auth.require(User.self)
            return user
                .$listWords
                .query(on: req.db)
                .sort(\.$createdAt, .descending)
                .all()
        }

        sentence.put("ignore") { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            let word = try req.content.get(String.self, at: "word").trimmingCharacters(in: .whitespacesAndNewlines)
            guard word.count > 0 else { throw Abort(.badRequest, reason: "Empty word passed.") }

            if !user.ignoreWords.contains(word) {
                user.ignoreWords.append(word)
            }
            return user.save(on: req.db)
                .map { Response(status: .ok) }
        }

        sentence.post("parse") { (req: Request) -> EventLoopFuture<[Sentence]> in
            let user = try req.auth.require(User.self)
            guard let sentenceString = req.body.string, sentenceString.count > 0 else { throw Abort(.badRequest, reason: "Empty sentence passed.") }
            let mecab = try Mecab()
            let nodes = try mecab.tokenize(string: sentenceString)
            let listWordsFuture = user.$listWords
                .query(on: req.db)
                .all()
            var sentences = try Sentence.parseMultiple(db: req.db, tokenizer: .init(nodes: nodes))
            return listWordsFuture
                .flatMap { listWords -> EventLoopFuture<[Sentence]> in
                    let offsets = sentences.enumerated().flatMap { (sentenceOffset, sentence) in
                        sentence.accentPhrases.enumerated().flatMap { (accentPhraseOffset, accentPhrase) in
                            accentPhrase.components.enumerated().map { (componentOffset, component) in
                                Offset(accentPhraseComponent: component, accentPhraseComponentOffset: componentOffset, accentPhraseOffset: accentPhraseOffset, sentenceOffset: sentenceOffset)
                            }
                        }
                    }

                    let offsetFutures: [EventLoopFuture<(Offset, [Headword])>] = offsets.map { offset in
                        let component = offset.accentPhraseComponent
                        if component.isBasic {
                            return req.eventLoop.future((offset, []))
                        }
                        return Headword.query(on: req.db)
                            .group(.or) {
                                $0.filter(\.$text == component.original.katakana)
                                  .filter(\.$text == component.surface.katakana)
                            }
                            .sort(\.$text)
                            .limit(3)
                            .all()
                            .map {
                                return (offset, $0)
                            }
                    }

                    return EventLoopFuture.whenAllSucceed(offsetFutures, on: req.eventLoop)
                        .map {
                            for (offset, headwords) in $0 {
                                sentences[offset.sentenceOffset].accentPhrases[offset.accentPhraseOffset].components[offset.accentPhraseComponentOffset].headwords = headwords
                                sentences[offset.sentenceOffset].accentPhrases[offset.accentPhraseOffset].components[offset.accentPhraseComponentOffset].listWords = listWords.filter { listWord in headwords.contains { $0.headline == listWord.value } }
                            }
                            return sentences
                        }
                }
        }
    }

}
