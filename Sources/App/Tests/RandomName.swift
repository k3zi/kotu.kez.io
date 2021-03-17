import MeCab
import Vapor

struct RandomName: Content {

    enum Gender: String, CaseIterable, Content {
        case male
        case female
    }

    let gender: Gender
    let firstName: RandomNames.Name
    let firstNameIndex: Int
    var firstNamePitchAccent: PitchAccent
    var firstNamePronunciation: String
    let lastName: RandomNames.Name
    let lastNameIndex: Int
    var lastNamePitchAccent: PitchAccent
    var lastNamePronunciation: String

    mutating func isMecabable() -> Bool {
        let mecab = try! Mecab()
        let nodes = try! mecab.tokenize(string: "\(lastName.kanji)\(firstName.kanji)").filter { $0.type == .normal }
        guard nodes.count == 2 && nodes[0].features[3] == "姓" && nodes[1].features[3] == "名" && nodes.allSatisfy({ $0.partOfSpeechSubType == "固有名詞" && $0.features[2] == "人名" && $0.pitchAccents.count == 1 }) else { return false }
        lastNamePitchAccent = nodes[0].pitchAccents[0]
        lastNamePronunciation = nodes[0].pronunciation
        firstNamePitchAccent = nodes[1].pitchAccents[0]
        firstNamePronunciation = nodes[1].pronunciation
        let pronunciation = nodes.map { $0.rawPronunciation }.joined()
        return pronunciation.katakana == "\(lastName.katakana)\(firstName.katakana)"
    }
}

func randomName() -> RandomName {
    let gender = RandomName.Gender.allCases.randomElement()!
    let firstNames = PitchAccentManager.shared.randomNames.firstNames
    let firstName = Array((gender == .female ? firstNames.female : firstNames.male).enumerated()).randomElement()!
    let lastName = Array(PitchAccentManager.shared.randomNames.lastNames.enumerated()).randomElement()!
    return .init(gender: gender, firstName: firstName.element, firstNameIndex: firstName.offset, firstNamePitchAccent: .init(mora: 0, length: 0), firstNamePronunciation: "", lastName: lastName.element, lastNameIndex: lastName.offset, lastNamePitchAccent: .init(mora: 0, length: 0), lastNamePronunciation: "")
}
