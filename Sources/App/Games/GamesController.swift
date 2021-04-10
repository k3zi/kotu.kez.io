import Fluent
import MeCab
import Vapor

let gamesDispatchQueue = DispatchQueue(label: "io.kez.kotu.games")
class GamesController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        var gameLobbies = [Lobby]()
        let games = routes.grouped("games")
            .grouped(App.User.guardMiddleware())

        let lobby = games.grouped("lobby")
        let lobbyID = lobby.grouped(":lobbyID")
        let lobbies = games.grouped("lobbies")

        lobbies.get { (req: Request) -> Page<Lobby.Response> in
            let filteredLobbies = gameLobbies.filter { $0.isPublic }.sorted(by: { $0.name > $1.name })
            let total = filteredLobbies.count
            let page = try req.query.decode(PageRequest.self)
            let start = (page.page - 1) * page.per
            let end = page.page * page.per
            return Page(
                items: Array(filteredLobbies.suffix(from: start).prefix(end - start).map { $0.response }),
                metadata: .init(
                    page: page.page,
                    per: page.per,
                    total: total
                )
            )
        }

        lobby.post { (req: Request) -> Lobby.Response in
            let user = try req.auth.require(User.self)
            let object = try req.content.decode(Lobby.Create.self)
            let lobby = Lobby(id: .init(), db: req.db, name: object.name, isPublic: object.isPublic, game: object.game, users: [
                .init(
                    id: .init(),
                    name: user.username,
                    userID: try user.requireID(),
                    isOwner: true
                )
            ])
            gamesDispatchQueue.sync {
                gameLobbies.append(lobby)
            }
            return lobby.response
        }

        lobbyID.post("join") { (req: Request) -> Lobby.User.Response in
            let user = try req.auth.require(User.self)
            let lobbyID = try req.parameters.require("lobbyID", as: UUID.self)
            guard let lobby = gameLobbies.first(where: { $0.id == lobbyID }) else {
                throw Abort(.notFound)
            }
            var gameUser: Lobby.User?
            try gamesDispatchQueue.sync {
                if let existingUser = lobby.users.first(where: { $0.userID == user.id }) {
                    gameUser = existingUser
                    return
                }
                gameUser = Lobby.User(id: .init(), name: user.username, userID: try user.requireID())
                lobby.users.append(gameUser!)
            }
            return gameUser!.response
        }

        lobbyID.webSocket(":id", "socket") { (req: Request, ws: WebSocket) in
            let user = req.auth.get(App.User.self) ?? App.User.guest
            guard let lobbyID = req.parameters.get("lobbyID", as: UUID.self), let id = req.parameters.get("id", as: UUID.self) else {
                return ws.close(promise: nil)
            }

            guard let lobby = gameLobbies.first(where: { $0.id == lobbyID }) else {
                return ws.close(promise: nil)
            }

            guard let gameUser = lobby.users.first(where: { $0.id == id && $0.userID == user.id }) else {
                return ws.close(promise: nil)
            }

            let connection = Lobby.User.Connection(id: .init(), ws: ws)
            gamesDispatchQueue.sync {
                gameUser.connections.append(connection)
                lobby.sendUpdate()
                lobby.handler.on(connection: connection, from: gameUser, in: lobby)
            }

            connection.ws.onText { (ws, text) in
                lobby.handler.on(text: text, from: gameUser, in: lobby)
            }

            ws.onClose.whenComplete { _ in
                gamesDispatchQueue.sync {
                    gameUser.connections.removeAll(where: { $0.id == connection.id })
                    lobby.sendUpdate()
                }
            }
        }

    }

}


