import Foundation

protocol WSEvent: Codable {
    static var eventName: String { get }
}

struct WSEventHolder<Event: WSEvent>: Codable {
    let name: String
    let data: Event
    let connectionID: String

    static func attemptDecodeUnwrap(type: Event.Type, jsonString: String, unwrappedCallback: (WSEventHolder<Event>) throws -> ()) rethrows {
        guard let data = jsonString.data(using: .utf8) else { return }
        guard let object = try? JSONDecoder().decode(WSEventHolder<Event>.self, from: data), object.name == type.eventName else { return }
        try unwrappedCallback(object)
    }
}

let wsEventEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

extension WSEvent {

    func jsonString(connectionID: String) -> String? {
        let payload = WSEventHolder(name: Self.eventName, data: self, connectionID: connectionID)
        return (try? wsEventEncoder.encode(payload)).flatMap({ String(data: $0, encoding: .utf8) })
    }

}

struct Hello: WSEvent {

    static let eventName = "hello"
    let id: String
    let color: String
    let canWrite: Bool
    let project: Project
    let messages: [Message]

}

struct NewSubtitle: WSEvent {

    struct ID: Codable {
        let id: UUID
    }

    static let eventName = "newSubtitle"
    let id: UUID
    let fragment: ID
    let translation: ID
    let text: String

}

struct UpdateSubtitle: WSEvent {

    static let eventName = "updateSubtitle"
    let id: UUID
    let text: String
    let selectionStart: Int?
    let selectionEnd: Int?
    var color: String?


}

struct BlurSubtitle: WSEvent {

    static let eventName = "blurSubtitle"
    let id: UUID

}

struct NewFragment: WSEvent {

    static let eventName = "newFragment"
    let id: UUID

}

struct NewTranslation: WSEvent {
    static let eventName = "newTranslation"
    let id: UUID
}

struct NewMessage: WSEvent {
    static let eventName = "message"
    let text: String
}

struct Message: WSEvent {
    static let eventName = "message"
    let text: String
    let color: String
    let username: String
}

struct DeleteFragment: WSEvent {

    static let eventName = "deleteFragment"
    let id: UUID

}

extension Fragment: WSEvent {
    static let eventName = "newFragment"
}

extension Translation: WSEvent {
    static let eventName = "newTranslation"
}
