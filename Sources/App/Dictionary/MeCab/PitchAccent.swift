import Vapor

struct PitchAccent: Content, Codable {

    static func pitchAccent(for morphemes: [Morpheme]) -> PitchAccent {
        if morphemes.count == 1 {
            return morphemes[0].pitchAccents[0]
        }

        /*let startNumbers = Array(morphemes.prefix(while: { $0.features[1] == "数詞" }))
        let endCounter = Array(morphemes.suffix(from: startNumbers.count))
        if endCounter.count == 1, let counter = endCounter.first, counter.features.contains("助数詞可能") {

        } else if startNumbers.count > 1 {
            let numberString = startNumbers.map { $0.surface }.joined()
            if let number = Int(numberString) {
                let reverseNumberString = String(number)
                if number
            }

        }*/

        var remaining = morphemes
        var morpheme = remaining.removeFirst()
        var buildUpWord = morpheme.pronunciation
        var accent = morpheme.pitchAccents[0]

        switch morpheme.pitchAccentModificationKind {
        case .dominant(m: let m):
            accent = PitchAccent(mora: buildUpWord.count - m, length: buildUpWord.moraCount)
        case .recessive(m: let m):
            if accent.descriptive == .heiban {
                accent = PitchAccent(mora: buildUpWord.count - m, length: buildUpWord.moraCount)
            }
        case .heibanHeadSameElseAccent(m: let m):
            if accent.mora > 1 {
                accent = PitchAccent(mora: accent.mora - m, length: buildUpWord.moraCount)
            }
        default:
            break
        }

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
                } else {
                    let i = buildUpWord.moraCount + secondHalfAccent.mora
                    buildUpWord += nextMorpheme.pronunciation
                    accent = PitchAccent(mora: i, length: buildUpWord.moraCount)
                }
            case .prefixDominant:
                wasPrefix = true
                buildUpWord += nextMorpheme.pronunciation
                accent = PitchAccent(mora: accent.mora, length: buildUpWord.moraCount)
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
            morpheme = nextMorpheme
            if wasPrefix {
                continue
            }
            let lastMorpheme = morphemes[0...max(0, morphemes.count - remaining.count - 2)].last(where: { m in ["名詞", "動詞", "形容詞"].contains(where: { m.partOfSpeech.contains($0) }) })
            var lastPartOfSpeech = lastMorpheme?.partOfSpeech ?? ""
            if lastPartOfSpeech.contains("名詞") {
                lastPartOfSpeech = "名詞"
            } else if lastPartOfSpeech.contains("動詞") {
                lastPartOfSpeech = "動詞"
            } else if lastPartOfSpeech.contains("形容詞") {
                lastPartOfSpeech = "形容詞"
            }

            kind = morpheme.pitchAccentCompoundKinds.first(where: { $0.canBeApplied(toPartOfSpeech: lastPartOfSpeech) })?.simple ?? (!morphemes.filter { $0.partOfSpeech == "名詞" }.isEmpty ? morpheme.pitchAccentCompoundKinds.first(where: { $0.canBeApplied(toPartOfSpeech: "名詞") })?.simple : .particleOriginal)
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
            case .heibanHeadSameElseAccent(m: let m):
                if accent.descriptive != .heiban && accent.descriptive != .atamadaka {
                    accent = PitchAccent(mora: accent.mora - m, length: buildUpWord.moraCount)
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


