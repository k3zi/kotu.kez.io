import MeCab
import Foundation

extension Node {

    var pitchAccentCompoundKinds: [PitchAccentConnectionKind] {
        let pitchCompounds = (features.count > 25 ? features[25] : "")
        // 名詞%F1,動詞%F2@0,形容詞%F2@-1
        let kindTokenizer = Tokenizer(input: pitchCompounds)
        var kinds = [String]()
        if pitchCompounds != "*" {
            while !kindTokenizer.reachedEnd {
                var kind = ""
                kindTokenizer.consume(while: ",")
                if kindTokenizer.next?.isKanji ?? false {
                    kind += kindTokenizer.consume(while: { a, _ in a.isKanji })
                    // Sometimes this doesn't appear: もん 動詞%F2@0,形容詞F2@-1
                    kindTokenizer.consume(while: "%")
                    kind += "%"
                }

                kind += kindTokenizer.consume(while: { a, _ in a.isLetter })
                kind += kindTokenizer.consume(while: { a, _ in a.isNumber })

                if kindTokenizer.hasPrefix("@") {
                    try? kindTokenizer.consume(expect: "@")
                    kind += "@"
                    func scanNumber() {
                        if kindTokenizer.hasPrefix("-") {
                            try? kindTokenizer.consume(expect: "-")
                            kind += "-"
                        }
                        kind += kindTokenizer.consume(while: { a, _ in a.isNumber })
                    }

                    scanNumber()
                    while kindTokenizer.next == "," && ((kindTokenizer.nextNext?.isNumber ?? false) || (kindTokenizer.nextNext == "-")) {
                        try? kindTokenizer.consume(expect: ",")
                        kind += ","
                        scanNumber()
                    }
                }
                kinds.append(kind)
            }
        }
        return kinds.map { PitchAccentConnectionKind(string: String($0)) }
    }

    var pitchAccentModificationKind: PitchAccentModificationKind {
        .init(string: (features.count > 26 ? features[26] : ""))
    }

    var pronunciation: String {
        // 6, 20, 21, 22, 23: ユウジュウ
        // 9, 11: ユージュー
        let nine = (features.count > 9 ? features[9] : "").split(separator: "-").first.flatMap { String($0) } ?? rawPronunciation
        return nine == "*" ? rawPronunciation : nine
    }

    var sapiPronunciation: String {
        let mainStress = "'"
        var result = ""
        var mora = 1
        var i = 0
        let pronunciation = Array(self.pronunciation)
        while i < pronunciation.count {
            result.append(pronunciation[i])
            i += 1
            while i < pronunciation.count && String.smallRowKanaExcludingSokuon.contains(pronunciation[i].unicodeScalars.first!) {
                result.append(pronunciation[i])
                i += 1
            }
            if mora == pitchAccents[0].mora {
                result += mainStress
            }
            mora += 1
        }
        return result
    }

    var rawPronunciation: String {
        (features.count > 6 ? features[6] : "").split(separator: "-").first.flatMap { String($0) } ?? ""
    }

    var surfacePronunciation: String {
        ((features.count > 22 ? features[22] : "").split(separator: "-").first.flatMap { String($0) } ?? "")
    }

    var ruby: String {
        //  使う → 使ウ
        // 入り込む → 入リ込ム
        let katakanaSurface = surface.katakana
        guard katakanaSurface != surfacePronunciation && !alwaysHideFurigana && !surfacePronunciation.isEmpty && surfacePronunciation != "*" else {
            return surface
        }

        let overlap = NeedlemanWunsch.align(input1: Array(katakanaSurface), input2: Array(surfacePronunciation))
        let zipped = Array(zip(overlap.output1, overlap.output2))
        enum Status {
            case none
            case matchFurigana(Int, Int?)
            case matchOkurigana(Int, Int?)
        }
        var status = Status.none
        var statuses = [(Status, ClosedRange<Int>)]()
        for i in zipped.startIndex..<zipped.endIndex {
            switch zipped[i] {
            case (.missing, .indexAndValue), (.indexAndValue, .missing):
                switch status {
                case .none:
                    status = .matchFurigana(i, nil)
                case let .matchFurigana(a, _):
                    status = .matchFurigana(a, i)
                case let .matchOkurigana(a, b):
                    statuses.append((status, a...(b ?? a)))
                    status = .matchFurigana(i, nil)
                }
            case let (.indexAndValue(_, valueA), .indexAndValue(_, valueB)):
                if valueA == valueB {
                    switch status {
                    case .none:
                        status = .matchOkurigana(i, nil)
                    case let .matchFurigana(a, b):
                        statuses.append((status, a...(b ?? a)))
                        status = .matchOkurigana(i, nil)
                    case let .matchOkurigana(a, _):
                        status = .matchOkurigana(a, i)
                    }
                } else {
                    switch status {
                    case .none:
                        status = .matchFurigana(i, nil)
                    case let .matchFurigana(a, _):
                        status = .matchFurigana(a, i)
                    case let .matchOkurigana(a, b):
                        statuses.append((status, a...(b ?? a)))
                        status = .matchFurigana(i, nil)
                    }
                }
            case (.missing, .missing):
                break
            }
        }
        switch status {
        case .none:
            break
        case let .matchFurigana(a, b), let .matchOkurigana(a, b):
            statuses.append((status, a...(b ?? a)))
        }

        var r = ""
        for (status, range) in statuses {
            switch status {
            case .matchFurigana:
                let kanji = overlap.output1[range].reduce(into: "", { (x, match) in
                    guard case let .indexAndValue(_, y) = match else {
                        return
                    }
                    x.append(y)
                })

                let pronunciation = overlap.output2[range].reduce(into: "", { (x, match) in
                    guard case let .indexAndValue(_, y) = match else {
                        return
                    }
                    x.append(y)
                })
                r += "<ruby>\(kanji.hiragana)<rt>\(pronunciation.hiragana)</rt></ruby>"
            case .matchOkurigana:
                let pronunciation = overlap.output2[range].reduce(into: "", { (x, match) in
                    guard case let .indexAndValue(_, y) = match else {
                        return
                    }
                    x.append(y)
                })
                r += "<ruby>\(pronunciation.hiragana)<rt></rt></ruby>"
            case .none:
                break
            }
        }
        return r
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
        ["助詞", "助動詞"].contains(partOfSpeech) || isPunctuation
    }

    var isPunctuation: Bool {
        ["補助記号", "空白"].contains(partOfSpeech)
    }

    func shouldIgnore(for user: User) -> Bool {
        isBasic
    }

    var isBasic: Bool {
        isBosEos || isGenerallyIgnored
    }

    var shouldDisplay: Bool {
        !isBosEos
    }

}

extension Character {

    var isKanji: Bool {
        String.cjkRanges.contains { $0.contains(self.unicodeScalars.first!.value) }
    }

}

extension String {

    static let smallRowKanaExcludingSokuon = CharacterSet(charactersIn: "ァィゥェォヵㇰヶㇱㇲㇳㇴㇵㇶㇷㇷ゚ㇸㇹㇺャュョㇻㇼㇽㇾㇿヮぁぃぅぇぉゃゅょゎ")

    var moraCount: Int {
        filter { !Self.smallRowKanaExcludingSokuon.contains($0.unicodeScalars.first!) }.count
    }

    static let cjkRanges: [ClosedRange<UInt32>] = [
        0x4E00...0x9FFF,   // main block
        0x3400...0x4DBF,   // extended block A
        0x20000...0x2A6DF, // extended block B
        0x2A700...0x2B73F, // extended block C
    ]

    var kanjiCount: Int {
        filter { $0.isKanji }.count
    }

    func isSpecialMora(at index: Int) -> Bool {
        let filtered = String(filter { !Self.smallRowKanaExcludingSokuon.contains($0.unicodeScalars.first!) })
        guard filtered.count > index else { return false }
        return ["っ", "ッ", "ー", "ん", "ン"].contains(String(filtered[filtered.index(filtered.startIndex, offsetBy: index)]))
    }

    func match(_ regex: String) -> [[String]] {
        let nsString = self as NSString
        return (try? NSRegularExpression(pattern: regex, options: [.dotMatchesLineSeparators]))?.matches(in: self, options: [], range: NSMakeRange(0, count)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : nsString.substring(with: match.range(at: $0)) }
        } ?? []
    }

}
