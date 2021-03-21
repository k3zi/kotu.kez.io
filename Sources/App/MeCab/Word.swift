import Vapor

struct Word: Content {

    enum Status: String, Content, Equatable {
        case unknown
        case learning
        case known
    }
    
    let word: String
    let status: Status
}
