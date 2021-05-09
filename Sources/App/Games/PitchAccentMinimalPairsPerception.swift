import Foundation
import FluentKit
import MeCab
import SQLKit
import Vapor

class PitchAccentMinimalPairsPerceptionGameData: GameData {
    var minimalPairs: App.MinimalPair?
    var minimalPair: App.MinimalPair.Pair?
    var userResponses: [Lobby.User: Int] = [:]
    var responseStartDate: Date?
    var responseExpiryDate: Date?
    var tick = 0
    var timeout: TimeInterval = 60
    var timer: DispatchSourceTimer?
}

struct PitchAccentMinimalPairsPerceptionGameHandler: GameHandler {

    struct StartGame: WSEvent {
        static let eventName = "startGame"
    }

    struct MinimalPair: WSEvent {
        struct Option: Codable {
            let pitchAccent: Int
            let moraCount: Int
            let accent: PitchAccentEntry.AccentGroup.Accent
        }
        static let eventName = "minimalPair"
        let soundFile: String
        let options: [Option]
        let tick: Int
        let expiresAt: Date
    }

    struct UserResponse: WSEvent {
        static let eventName = "userResponse"
        let pitchAccent: Int
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
            timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .seconds(0))
            timer.setEventHandler { [weak lobby] in
                guard let lobby = lobby, lobby.state == .inProgress, let data = lobby.data as? PitchAccentMinimalPairsPerceptionGameData else {
                    return timer.cancel()
                }

                let timeoutReached = data.responseStartDate != nil && abs(data.responseStartDate!.timeIntervalSinceNow) > data.timeout

                if (data.userResponses.count == lobby.users.count || timeoutReached) && timerTick != data.tick {
                    data.userResponses = [:]
                    data.tick += 1
                    data.responseStartDate = nil
                    timerTick = data.tick
                    sendSubtitle(lobby: lobby)
                }
            }
            timer.resume()
            (lobby.data as? PitchAccentMinimalPairsPerceptionGameData)?.timer = timer
        }

        WSEventHolder.attemptDecodeUnwrap(type: UserResponse.self, jsonString: text) { holder in
            guard lobby.state == .inProgress, let data = lobby.data as? PitchAccentMinimalPairsPerceptionGameData else {
                return
            }

            guard data.tick == holder.data.tick, !data.userResponses.contains(where: { $0.key == user }), let answer = data.minimalPair else {
                return
            }

            let response = holder.data.pitchAccent
            data.userResponses[user] = response
            let score = response == answer.pitchAccent ? 5 : 0
            user.score += score
            if user.score >= 100 {
                lobby.state = .finished
            }
            lobby.sendUpdate()
        }
    }

    func on(connection: Lobby.User.Connection, from user: Lobby.User, in lobby: Lobby) {
        guard lobby.state == .inProgress, let data = lobby.data as? PitchAccentMinimalPairsPerceptionGameData, let options = data.minimalPairs?.pairs, let selection = data.minimalPair, let expiryDate = data.responseExpiryDate else {
            return
        }
        let event = MinimalPair(soundFile: selection.soundFile, options: options.map { .init(pitchAccent: $0.pitchAccent, moraCount: $0.entries[0].moraCount, accent: $0.entries[0].accents[0].accent[0]) }, tick: data.tick, expiresAt: expiryDate)
        if let eventString = event.jsonString(connectionID: connection.id.uuidString) {
            connection.ws.send(eventString)
        }
    }

    func sendSubtitle(lobby: Lobby) {
        guard let randomPairs = PitchAccentManager.shared.minimalPairs.randomElement() else { return }
        guard let randomPair = randomPairs.pairs.randomElement() else { return }
        guard let data = lobby.data as? PitchAccentMinimalPairsPerceptionGameData else { return }
        let startDate = Date()
        let expiryDate = startDate.addingTimeInterval(data.timeout)
        data.minimalPairs = randomPairs
        data.minimalPair = randomPair
        data.userResponses = [:]
        data.responseStartDate = startDate
        data.responseExpiryDate = expiryDate
        data.tick += 1
        let event = MinimalPair(soundFile: randomPair.soundFile, options: randomPairs.pairs.map { .init(pitchAccent: $0.pitchAccent, moraCount: $0.entries[0].moraCount, accent: $0.entries[0].accents[0].accent[0]) }, tick: data.tick, expiresAt: expiryDate)
        lobby.sendToEveryone(event: event)
    }
}
