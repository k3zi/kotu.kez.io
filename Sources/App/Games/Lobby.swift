import Foundation
import Vapor
import FluentKit

protocol GameData {}
protocol GameHandler {
    func on(text: String, from user: Lobby.User, in lobby: Lobby)
    func on(connection: Lobby.User.Connection, from user: Lobby.User, in lobby: Lobby)
}

final class Lobby {

    enum Game: String, Codable {
        case transcribe
        case pitchAccentMinimalPairsPerception

        func newData() -> GameData {
            switch self {
            case .transcribe:
                return TranscribeGameData()
            case .pitchAccentMinimalPairsPerception:
                return PitchAccentMinimalPairsPerceptionGameData()
            }
        }

        func newHandler() -> GameHandler {
            switch self {
            case .transcribe:
                return TranscribeGameHandler()
            case .pitchAccentMinimalPairsPerception:
                return PitchAccentMinimalPairsPerceptionGameHandler()
            }
        }
    }

    enum State: String, Codable {
        case notStarted
        case inProgress
        case abandoned
        case finished
    }

    let id: UUID
    let db: Database
    let name: String
    let isPublic: Bool
    let game: Game
    let handler: GameHandler

    var state: State
    var data: GameData
    var lastActive: Date = .init()
    var users: [Lobby.User]

    init(id: UUID, db: Database, name: String, isPublic: Bool, game: Game, users: [User]) {
        self.id = id
        self.db = db
        self.name = name
        self.isPublic = isPublic
        self.game = game
        self.state = .notStarted
        self.users = users
        self.data = game.newData()
        self.handler = game.newHandler()

        let timer = DispatchSource.makeTimerSource(queue: gamesDispatchQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(30), leeway: .seconds(0))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.state != .abandoned else {
                return timer.cancel()
            }

            var changed = false
            for user in self.users {
                if user.connections.isEmpty && abs(user.lastActive.timeIntervalSinceNow) > 120 {
                    self.users.removeAll(where: { $0.id == user.id })
                    changed = true
                }
            }

            if changed {
                self.sendUpdate()
            }

            if self.users.count == 0 {
                self.state = .abandoned
                timer.cancel()
            }
        }
        timer.resume()
    }

    func sendToEveryone(event: WSEvent) {
        for user in users {
            for connection in user.connections {
                if let responseString = event.jsonString(connectionID: user.id.uuidString) {
                    connection.ws.send(responseString)
                }
            }
        }
    }

    func sendToEach(_ event: (User) -> WSEvent) {
        for user in users {
            let userEvent = event(user)
            for connection in user.connections {
                if let responseString = userEvent.jsonString(connectionID: connection.id.uuidString) {
                    connection.ws.send(responseString)
                }
            }
        }
    }

    func sendUpdate() {
        sendToEach {
            Lobby.Update(lobby: response, user: $0.response)
        }
    }

    func on(text: String, from user: Lobby.User) {
        lastActive = .init()
        user.lastActive = lastActive
        handler.on(text: text, from: user, in: self)
    }

    func on(connection: Lobby.User.Connection, from user: Lobby.User) {
        lastActive = .init()
        user.lastActive = lastActive
        handler.on(connection: connection, from: user, in: self)
    }

    var response: Response {
        .init(id: id, name: name, isPublic: isPublic, game: game, state: state, users: users.map { $0.response })
    }

    struct Response: Content {

        let id: UUID
        let name: String
        let isPublic: Bool
        let game: Game
        let state: State
        let users: [User.Response]
    }

    struct Create: Content {
        let name: String
        let isPublic: Bool
        let game: Game
    }

    struct Update: WSEvent, Content {
        static let eventName = "update"

        let lobby: Lobby.Response
        let user: User.Response
    }

}

extension Lobby {

    class User: Hashable {

        static func == (lhs: Lobby.User, rhs: Lobby.User) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        struct Connection {
            let id: UUID
            let ws: WebSocket
        }

        let id: UUID
        let name: String
        let userID: UUID?
        var isOwner: Bool
        var connections: [Connection]
        var score: Int
        var lastActive: Date = .init()

        init(id: UUID, name: String, userID: UUID?, isOwner: Bool = false) {
            self.id = id
            self.name = name
            self.userID = userID
            self.isOwner = isOwner
            self.connections = []
            self.score = 0
        }

        var response: Response {
            .init(id: id, name: name, isOwner: isOwner, score: score)
        }

        struct Response: Content {
            let id: UUID
            let name: String
            let isOwner: Bool
            let score: Int
        }

    }

}
