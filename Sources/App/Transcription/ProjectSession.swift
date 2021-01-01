import Fluent
import Vapor

extension Array: WSEvent where Element == ProjectSession.Connection.User {
    static var eventName: String {
        "usersList"
    }
}

let sessionDispatchQueue = DispatchQueue(label: "io.kez.kotu.transcription.project.session")

class ProjectSession {

    class Connection: Equatable {

        struct User: Codable {

            struct Edit: Codable {
                let subtitleID: UUID
                let lastText: String
                let selectionStart: Int?
                let selectionEnd: Int?
            }

            let id: String
            let username: String
            let color: String
            var edit: Edit?

        }

        let id: String
        var user: User
        let ws: WebSocket

        init(id: String, color: String, databaseUser: App.User, ws: WebSocket) {
            self.id = id
            self.user = User(id: databaseUser.id!.uuidString, username: databaseUser.username, color: color, edit: nil)
            self.ws = ws
        }

        static func == (lhs: Connection, rhs: Connection) -> Bool {
            lhs.id == rhs.id
        }
    }

    let projectID: UUID
    private var connections = [Connection]()

    init(project: Project) {
        self.projectID = project.id!
    }

    var existingColors: [String] {
        sessionDispatchQueue.sync {
            connections.map { $0.user.color }
        }
    }

    func sendUsersList() {
        sessionDispatchQueue.sync {
            for connection in connections {
                let otherConnections = connections.filter { $0 != connection }
                let otherUsers = otherConnections.map { $0.user }
                let payloadString = otherUsers.jsonString(connectionID: connection.id)!
                connection.ws.send(payloadString)
            }
        }
    }

    func add(db: FluentKit.Database, connection: Connection) {
        let projectID = self.projectID
        let connectionID = connection.id
        connection.ws.onText { [weak self] (ws, text) in
            guard let self = self else { return}

            WSEventHolder.attemptDecodeUnwrap(type: DeleteFragment.self, jsonString: text) { holder in
                guard let string = holder.data.jsonString(connectionID: connectionID) else { return }
                sessionDispatchQueue.sync {
                    self.connections.filter { $0 != connection }
                        .forEach { $0.ws.send(string) }
                }
            }

            WSEventHolder.attemptDecodeUnwrap(type: NewFragment.self, jsonString: text) { holder in
                let id = holder.data.id
                Fragment.query(on: db)
                    .with(\.$project)
                    .with(\.$subtitles) { subtitle in
                        subtitle.with(\.$translation)
                    }
                    .filter(\.$id == id)
                    .first()
                    .unwrap(or: Abort(.badRequest))
                    .guard({ $0.project.id == projectID }, else: Abort(.badRequest))
                    .whenSuccess { [weak self] fragment in
                        guard let string = fragment.jsonString(connectionID: connectionID) else { return }
                        sessionDispatchQueue.sync {
                            self?.connections.filter { $0 != connection }
                                .forEach { $0.ws.send(string) }
                        }
                    }
            }

            WSEventHolder.attemptDecodeUnwrap(type: NewTranslation.self, jsonString: text) { holder in
                let id = holder.data.id
                Translation.query(on: db)
                    .with(\.$project)
                    .with(\.$language)
                    .filter(\.$id == id)
                    .first()
                    .unwrap(or: Abort(.badRequest))
                    .guard({ $0.project.id == projectID }, else: Abort(.badRequest))
                    .whenSuccess { [weak self] translation in
                        guard let string = translation.jsonString(connectionID: connectionID) else { return }
                        sessionDispatchQueue.sync {
                            self?.connections.filter { $0 != connection }
                                .forEach { $0.ws.send(string) }
                        }
                    }
            }

            WSEventHolder.attemptDecodeUnwrap(type: BlurSubtitle.self, jsonString: text) { holder in
                if connection.user.edit?.subtitleID == holder.data.id {
                    connection.user.edit = nil
                }
                self.sendUsersList()
            }

            WSEventHolder.attemptDecodeUnwrap(type: NewSubtitle.self, jsonString: text) { holder in
                Subtitle
                    .query(on: db)
                    .filter(\.$id == holder.data.id)
                    .with(\.$translation) { $0.with(\.$project) }
                    .first()
                    .unwrap(or: Abort(.badRequest))
                    .guard({ $0.translation.project.id == projectID }, else: Abort(.badRequest))
                    .whenSuccess { [weak self] _ in
                        guard let string = holder.data.jsonString(connectionID: connectionID) else { return }
                        sessionDispatchQueue.sync {
                            self?.connections.filter { $0 != connection }
                                .forEach {
                                    $0.ws.send(string)
                                }
                        }
                    }
            }

            WSEventHolder.attemptDecodeUnwrap(type: UpdateSubtitle.self, jsonString: text) { holder in
                Subtitle
                    .query(on: db)
                    .filter(\.$id == holder.data.id)
                    .with(\.$translation) { $0.with(\.$project) }
                    .first()
                    .unwrap(or: Abort(.badRequest))
                    .guard({ $0.translation.project.id == projectID }, else: Abort(.badRequest))
                    .whenSuccess { [weak self] _ in
                        sessionDispatchQueue.sync {
                            for connection in self?.connections ?? [] {
                                if connection.user.edit?.subtitleID == holder.data.id {
                                    connection.user.edit = nil
                                }
                            }
                        }
                        connection.user.edit = Connection.User.Edit(subtitleID: holder.data.id, lastText: holder.data.text, selectionStart: holder.data.selectionStart, selectionEnd: holder.data.selectionEnd)
                        var data = holder.data
                        data.color = connection.user.color
                        guard let string = data.jsonString(connectionID: connectionID) else { return }
                        sessionDispatchQueue.sync {
                            self?.connections.filter { $0 != connection }
                                .forEach {
                                    $0.ws.send(string)
                                }
                        }
                        self?.sendUsersList()
                    }
            }
        }
        sessionDispatchQueue.sync {
            connections.append(connection)
        }
    }

    func remove(id: String) {
        sessionDispatchQueue.sync {
            connections.removeAll(where: { $0.id == id })
        }
        sendUsersList()
    }

}
