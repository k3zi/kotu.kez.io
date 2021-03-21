import Vapor

enum Frequency: String, Content, Comparable {
    case veryCommon
    case common
    case uncommon
    case rare
    case veryRare
    case unknown

    var rank: Int {
        switch self {
        case .veryCommon: return 1
        case .common: return 2
        case .uncommon: return 3
        case .rare: return 4
        case .veryRare: return 5
        case .unknown: return 6
        }
    }

    static func <(lhs: Frequency, rhs: Frequency) -> Bool {
        return lhs.rank < rhs.rank
    }
}

struct FrequencyListElement: Decodable, Comparable {

    static func <(lhs: FrequencyListElement, rhs: FrequencyListElement) -> Bool {
        return lhs.frequency < rhs.frequency
    }

    let numberOfTimes: Int
    let word: String
    let frequencyGroup: Int
    let frequencyRank: Int
    let percentage: Double
    let cumulativePercentage: Double
    let partOfSpeech: String

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        numberOfTimes = Int(try container.decode(String.self))!
        word = try container.decode(String.self)
        frequencyGroup = Int(try container.decode(String.self))!
        frequencyRank = Int(try container.decode(String.self))!
        percentage = Double(try container.decode(String.self))!
        cumulativePercentage = Double(try container.decode(String.self))!
        partOfSpeech = try container.decode(String.self)
    }

    var frequency: Frequency {
        switch frequencyGroup {
        case (..<1000):
            return .veryCommon
        case (..<5000):
            return .common
        case (..<10000):
            return .uncommon
        case (..<20000):
            return .rare
        default:
            return .veryRare
        }
    }

}

struct DifficultyListElement: Decodable {

    let id: Int
    let word: String
    let katakana: String
    let difficultyRank: Int

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        id = Int(try container.decode(String.self))!
        word = try container.decode(String.self)
        katakana = try container.decode(String.self)
        difficultyRank = Int(try container.decode(String.self).components(separatedBy: ".").first!)!
    }

}
