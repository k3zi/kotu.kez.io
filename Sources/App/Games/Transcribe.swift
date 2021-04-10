import Foundation
import FluentKit
import MeCab
import SQLKit
import Vapor

class TranscribeGameData: GameData {
    var subtitle: AnkiDeckSubtitle?
    var userResponses: [Lobby.User: String] = [:]
    var responseStartDate: Date?
    var tick = 0
    var timer: DispatchSourceTimer?
}

struct TranscribeGameHandler: GameHandler {

    struct StartGame: WSEvent {
        static let eventName = "startGame"
    }

    struct Subtitle: WSEvent {
        static let eventName = "subtitle"
        let externalFileID: UUID
        let tick: Int
    }

    struct UserResponse: WSEvent {
        static let eventName = "userResponse"
        let text: String
        let tick: Int
    }

    func on(text: String, from user: Lobby.User, in lobby: Lobby) {
        WSEventHolder.attemptDecodeUnwrap(type: StartGame.self, jsonString: text) { holder in
            guard user.isOwner, lobby.state == .notStarted || lobby.state == .finished else {
                return
            }

            lobby.state = .inProgress
            lobby.users.forEach { $0.score = 0 }
            lobby.sendUpdate()
            sendSubtitle(lobby: lobby)
            let timer = DispatchSource.makeTimerSource(queue: gamesDispatchQueue)
            var timerTick = -1
            timer.schedule(deadline: .now(), repeating: 1, leeway: .seconds(0))
            timer.setEventHandler { [weak lobby] in
                guard let lobby = lobby, lobby.state == .inProgress, let data = lobby.data as? TranscribeGameData else {
                    return timer.cancel()
                }

                let timeoutReached = data.responseStartDate != nil && abs(data.responseStartDate!.timeIntervalSinceNow) > 60

                if (data.userResponses.count == lobby.users.count || timeoutReached) && timerTick != data.tick {
                    data.userResponses = [:]
                    data.tick += 1
                    data.responseStartDate = nil
                    timerTick = data.tick
                    sendSubtitle(lobby: lobby)
                }
            }
            timer.resume()
            (lobby.data as? TranscribeGameData)?.timer = timer
        }

        WSEventHolder.attemptDecodeUnwrap(type: UserResponse.self, jsonString: text) { holder in
            guard lobby.state == .inProgress, let data = lobby.data as? TranscribeGameData else {
                return
            }

            guard data.tick == holder.data.tick, !data.userResponses.contains(where: { $0.key == user }), let subtitle = data.subtitle else {
                return
            }

            let response = holder.data.text
            data.userResponses[user] = response
            let score = max(0, subtitle.text.count - subtitle.text.editDistance(to: response))
            user.score += score
            if user.score >= 100 {
                lobby.state = .finished
            }
            lobby.sendUpdate()
        }
    }

    func on(connection: Lobby.User.Connection, from user: Lobby.User, in lobby: Lobby) {
        guard lobby.state == .inProgress, let data = lobby.data as? TranscribeGameData,let subtitle = data.subtitle else {
            return
        }
        let event = Subtitle(externalFileID: subtitle.$externalFile.id, tick: data.tick)
        if let eventString = event.jsonString(connectionID: connection.id.uuidString) {
            connection.ws.send(eventString)
        }
    }

    func sendSubtitle(lobby: Lobby) {
        guard let randomFrequencyItem = DictionaryManager.shared.frequencyList.filter({ $0.value.frequency == .veryCommon }).randomElement()?.value else {
            return
        }

        return AnkiDeckSubtitle.query(on: lobby.db)
            .filter(\.$text, .custom("LIKE"), "%\(randomFrequencyItem.word)%")
            .filter(DatabaseQuery.Filter.sql(SQLFunction("LENGTH", args: SQLColumn("text")), SQLBinaryOperator.lessThan, SQLLiteral.numeric("30")))
            .sort(DatabaseQuery.Sort.sql(raw: "RANDOM()"))
            .first()
            .unwrap(or: Abort(.notFound))
            .whenComplete { [weak lobby] result in
                guard let lobby = lobby, let data = lobby.data as? TranscribeGameData else { return }
                switch result {
                case .success(let subtitle):
                    data.subtitle = subtitle
                    data.userResponses = [:]
                    data.responseStartDate = Date()
                    data.tick += 1
                    let event = Subtitle(externalFileID: subtitle.$externalFile.id, tick: data.tick)
                    lobby.sendToEveryone(event: event)
                case .failure:
                    sendSubtitle(lobby: lobby)
                }
            }
    }
}
