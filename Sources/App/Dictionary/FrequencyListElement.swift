import Vapor

enum Frequency: String, Content {
    case veryCommon
    case common
    case uncommon
    case rare
    case veryRare
    case unknown
}

struct FrequencyListElement: Decodable {

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
