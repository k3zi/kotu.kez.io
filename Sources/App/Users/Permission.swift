import Fluent
import Vapor

enum Permission: String, Codable {
    case admin
    case blog
    case api
    case subtitles
}

extension Permission: LosslessStringConvertible {
    init?(_ description: String) {
        self.init(rawValue: description)
    }
    var description: String {
        rawValue
    }
}
