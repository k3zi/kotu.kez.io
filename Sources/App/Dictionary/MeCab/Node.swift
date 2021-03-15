import MeCab
import Foundation

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
        guard katakanaSurface != surfacePronunciation && !alwaysHideFurigana else {
            return surface
        }

        //  使ウ → (.+)ウ
        // 入リ込ム → (.+)リ(.+)ム
        let regexString = katakanaSurface.replacingOccurrences(of: "\\p{Han}+", with: "(.+)", options: [.regularExpression])

        // [ツカ]
        // [ハイ, コ]
        var captures = surfacePronunciation.match(regexString).first?.suffix(from: 1) ?? []
        guard !captures.isEmpty else {
            return "<ruby><rb>\(surface)</rb><rt>\(surfacePronunciation)</rt></ruby>"
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

extension String {

    static let smallRowKanaExcludingSokuon = CharacterSet(charactersIn: "ァィゥェォヵㇰヶㇱㇲㇳㇴㇵㇶㇷㇷ゚ㇸㇹㇺャュョㇻㇼㇽㇾㇿヮぁぃぅぇぉゃゅょゎ")

    var moraCount: Int {
        filter { !Self.smallRowKanaExcludingSokuon.contains($0.unicodeScalars.first!) }.count
    }

    func isSpecialMora(at index: Int) -> Bool {
        let filtered = String(filter { !Self.smallRowKanaExcludingSokuon.contains($0.unicodeScalars.first!) })
        guard filtered.count > index else { return false }
        return ["っ", "ッ", "ー", "ん", "ン"].contains(String(filtered[filtered.index(filtered.startIndex, offsetBy: index)]))
    }

    func match(_ regex: String) -> [[String]] {
        let nsString = self as NSString
        return (try? NSRegularExpression(pattern: regex, options: []))?.matches(in: self, options: [], range: NSMakeRange(0, count)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : nsString.substring(with: match.range(at: $0)) }
        } ?? []
    }

}
