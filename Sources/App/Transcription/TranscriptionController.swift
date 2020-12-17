import Fluent
import Vapor

extension Array: WSEvent where Element == ProjectSession.Connection.User {
    static var eventName: String {
        "usersList"
    }
}

fileprivate let sessionDispatchQueue = DispatchQueue(label: "io.kez.kotu.transcription.project.session")

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

class TranscriptionController: RouteCollection {

    var projectSessions = [UUID: ProjectSession]()

    func session(for project: Project) -> ProjectSession? {
        guard let id = project.id else { return nil }
        return sessionDispatchQueue.sync {
            let session = projectSessions[id, default: ProjectSession(project: project)]
            projectSessions[id] = session
            return session
        }
    }

    func boot(routes: RoutesBuilder) throws {
        let transcription = routes.grouped("transcription")
            .grouped(User.guardMiddleware())

        transcription.get("invites") { req -> EventLoopFuture<[Invite]> in
            let user = try req.auth.require(User.self)
            return user.$invites
                .query(on: req.db)
                .with(\.$project) {
                    $0.with(\.$translations) {
                        $0.with(\.$language)
                    }.with(\.$owner)
                }
                .all()
        }

        let projects = transcription.grouped("projects")

        projects.get { req -> EventLoopFuture<[Project]> in
            let user = try req.auth.require(User.self)
            return user.$projects
                .query(on: req.db)
                .with(\.$translations) { translation in
                    translation.with(\.$language)
                }
                .all()
                .flatMap { ownedProjects in
                    user.$shares.query(on: req.db)
                        .with(\.$project) {
                            $0.with(\.$translations) {
                                $0.with(\.$language)
                            }
                        }
                        .all()
                        .map { $0.map { $0.project }}
                        .map { ($0 + ownedProjects) }
                        .map { $0.sorted(by: { $0.name > $1.name })}
                }
        }

        let project = transcription.grouped("project")
        project.post("create") { req -> EventLoopFuture<Project> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()

            try Project.Create.validate(content: req)
            let object = try req.content.decode(Project.Create.self)
            return Language.find(object.languageID, on: req.db)
                .unwrap(orError: Abort(.badRequest, reason: "Language not found"))
                .throwingFlatMap { language in
                    guard let languageID = language.id else { throw Abort(.internalServerError, reason: "Could not access language ID") }
                    let project = Project(ownerID: userID, name: object.name, youtubeID: object.youtubeID)

                    return project
                        .save(on: req.db)
                        .throwingFlatMap {
                            guard let projectID = project.id else { throw Abort(.internalServerError, reason: "Could not access project ID") }
                            let translation = Translation(projectID: projectID, languageID: languageID, isOriginal: true)
                            return translation.save(on: req.db)
                        }
                        .map { project }
                }
        }

        project.get(":id") { (req: Request) -> EventLoopFuture<Project> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            // In the future do a join for shared projects.
            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .with(\.$translations) { translation in
                    translation.with(\.$language)
                }
                .with(\.$fragments) { fragments in
                    fragments.with(\.$subtitles) { subtitle in
                        subtitle.with(\.$translation)
                    }
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
        }

        // MARK: Socket

        project.webSocket(":id", "socket") { (req: Request, ws: WebSocket) in
            guard let user = try? req.auth.require(User.self), let userID = try? user.requireID(), let projectID = req.parameters.get("id", as: UUID.self) else {
                return ws.close(promise: nil)
            }

            let projectCall = Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .filter(\.$id == projectID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
            projectCall.whenFailure({ _ in
                ws.close(promise: nil)
            })
            projectCall.whenSuccess({ [unowned self] project in
                guard let session = self.session(for: project) else {
                    return ws.close(promise: nil)
                }

                let wsID = UUID().uuidString
                let existingColors = session.existingColors
                let randomColors = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal", "cyan"]
                let onceRandomColors = randomColors.filter { !existingColors.contains($0) }
                let color = onceRandomColors.randomElement() ?? randomColors.randomElement()!
                let hello = Hello(id: wsID, color: color)
                guard let jsonString = hello.jsonString(connectionID: wsID) else {
                    return ws.close(promise: nil)
                }
                ws.send(jsonString)
                session.add(db: req.db, connection: .init(id: wsID, color: color, databaseUser: user, ws: ws))
                session.sendUsersList()

                ws.onClose.whenComplete { _ in
                    session.remove(id: wsID)
                }
            })
        }

        // MARK: Invites

        project.post(":id", "invite", ":username") { (req: Request) -> EventLoopFuture<Invite> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let username = req.parameters.get("username", as: String.self) else { throw Abort(.badRequest, reason: "Username not provided") }
            guard user.username != username else { throw Abort(.badRequest, reason: "You are not permitted to invite yourself") }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .with(\.$invites) {
                    $0.with(\.$invitee)
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .flatMap { project in
                    User.query(on: req.db)
                        .filter(\.$username == username)
                        .first()
                        .unwrap(orError: Abort(.badRequest, reason: "User not found"))
                        .throwingFlatMap { invitee in
                            let projectID = try project.requireID()
                            let inviteeID = try invitee.requireID()
                            guard !project.shares.contains(where: { $0.sharedUser.id == inviteeID }) else {
                                throw Abort(.badRequest, reason: "This user has already accepted an invite")
                            }

                            guard !project.invites.contains(where: { $0.invitee.id == inviteeID }) else {
                                throw Abort(.badRequest, reason: "An invite already exists for this user")
                            }

                            let invite = Invite(projectID: projectID, inviteeID: inviteeID)
                            return invite.save(on: req.db)
                                .map { invite }
                        }
                }
        }

        project.post(":id", "invite", "accept") { (req: Request) -> EventLoopFuture<Share> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let projectID = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$invites) {
                    $0.with(\.$invitee)
                }
                .filter(\.$id == projectID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .throwingFlatMap { project in
                    guard let invite = project.invites.first(where: { $0.invitee.id == userID }) else {
                        throw Abort(.badRequest, reason: "You do not have an invite for this project")
                    }

                    return invite.delete(on: req.db)
                        .throwingFlatMap {
                            let projectID = try project.requireID()
                            let share = Share(projectID: projectID, sharedUserID: userID)
                            return share.save(on: req.db)
                                .map { share }
                        }
                }
        }

        project.post(":id", "invite", "decline") { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let projectID = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$invites) {
                    $0.with(\.$invitee)
                }
                .filter(\.$id == projectID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .throwingFlatMap { project in
                    guard let invite = project.invites.first(where: { $0.invitee.id == userID }) else {
                        throw Abort(.badRequest, reason: "You do not have an invite for this project")
                    }

                    return invite.delete(on: req.db)
                        .map { Response(status: .ok) }
                }
        }

        // MARK: Translation

        project.post(":id", "translation", "create") { (req: Request) -> EventLoopFuture<Translation> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try Translation.Create.validate(content: req)
            let object = try req.content.decode(Translation.Create.self)

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .flatMap { project in
                    Language.find(object.languageID, on: req.db)
                        .unwrap(orError: Abort(.badRequest, reason: "Language not found"))
                        .throwingFlatMap { language in
                            let projectID = try project.requireID()
                            let languageID = try language.requireID()
                            let translation = Translation(projectID: projectID, languageID: languageID, isOriginal: false)
                            return translation.save(on: req.db)
                                .map { translation }
                        }
                }
        }

        // MARK: Fragment

        project.post(":id", "fragment", "create") { (req: Request) -> EventLoopFuture<Fragment> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try Fragment.Create.validate(content: req)
            let object = try req.content.decode(Fragment.Create.self)
            guard object.startTime <= object.endTime else {
                throw Abort(.badRequest, reason: "Start time can not be greater than end time")
            }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$translations)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .throwingFlatMap { project in
                    let fragment = Fragment(projectID: try project.requireID(), startTime: object.startTime, endTime: object.endTime)
                    return fragment.save(on: req.db)
                        .throwingFlatMap {
                            guard let baseTranslation = project.translations.first(where: { $0.id == object.baseTranslationID }) else {
                                throw Abort(.unauthorized, reason: "Base translation could not be found")
                            }
                            var subtitles = [Subtitle]()
                            let baseSubtitle = Subtitle(translationID: try baseTranslation.requireID(), fragmentID: try fragment.requireID(), text: object.baseText)
                            subtitles.append(baseSubtitle)
                            
                            if let targetText = object.targetText, targetText.count > 0, let targetTranslationID = object.targetTranslationID {
                                guard let targetTranslation = project.translations.first(where: { $0.id == targetTranslationID }) else {
                                    throw Abort(.unauthorized, reason: "Target translation could not be found")
                                }

                                let targetSubtitle = Subtitle(translationID: try targetTranslation.requireID(), fragmentID: try fragment.requireID(), text: targetText)
                                subtitles.append(targetSubtitle)
                            }
                            return fragment.$subtitles.create(subtitles, on: req.db)
                        }
                        .map { fragment }
                }
        }

        project.delete(":id", "fragment", ":fragmentID") { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let projectID = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let fragmentID = req.parameters.get("fragmentID", as: UUID.self) else { throw Abort(.badRequest, reason: "Fragment ID not provided") }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .filter(\.$id == projectID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .throwingFlatMap { project in
                    project.$fragments
                        .query(on: req.db)
                        .with(\.$subtitles)
                        .filter(\.$id == fragmentID)
                        .first()
                        .unwrap(or: Abort(.badRequest, reason: "Fragment not found"))
                        .flatMap { fragment in
                            fragment.subtitles.delete(on: req.db)
                                .flatMap {
                                    fragment.delete(on: req.db)
                                }
                        }
                        .map { Response(status: .ok) }
                }
        }

        project.post(":id", "subtitle", "create") { (req: Request) -> EventLoopFuture<Subtitle> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "Project ID not provided") }

            try Subtitle.Create.validate(content: req)
            let object = try req.content.decode(Subtitle.Create.self)
            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .with(\.$translations)
                .with(\.$fragments) { $0.with(\.$subtitles) { $0.with(\.$translation) } }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .throwingFlatMap { project in
                    guard let translation = project.translations.first(where: { $0.id == object.translationID }) else {
                        throw Abort(.unauthorized, reason: "Translation could not be found")
                    }

                    guard let fragment = project.fragments.first(where: { $0.id == object.fragmentID }) else {
                        throw Abort(.unauthorized, reason: "Fragment could not be found")
                    }

                    guard !fragment.subtitles.contains(where: { $0.translation.id == translation.id }) else {
                        throw Abort(.unauthorized, reason: "Duplicate subtitle found")
                    }

                    let subtitle = Subtitle(translationID: try translation.requireID(), fragmentID: try fragment.requireID(), text: object.text)
                    return subtitle.save(on: req.db)
                        .map { subtitle }
                }
        }

        project.put(":id", "subtitle", ":subtitleID") { (req: Request) -> EventLoopFuture<Subtitle> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "Project ID not provided") }
            guard let subtitleID = req.parameters.get("subtitleID", as: UUID.self) else { throw Abort(.badRequest, reason: "Subtitle ID not provided") }

            try Subtitle.Update.validate(content: req)
            let object = try req.content.decode(Subtitle.Update.self)
            return Subtitle.query(on: req.db)
                .with(\.$fragment) {
                    $0.with(\.$project) {
                        $0.with(\.$owner)
                            .with(\.$shares) {
                                $0.with(\.$sharedUser)
                            }
                    }
                }
                .filter(\.$id == subtitleID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Subtitle not found"))
                .guard({ $0.fragment.project.owner.id == userID || $0.fragment.project.shares.contains(where: { $0.sharedUser.id == userID }) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .guard({ $0.fragment.project.id == id }, else: Abort(.unauthorized, reason: "Subtitle does not belong to this project"))
                .flatMap { subtitle in
                    subtitle.text = object.text
                    return subtitle.update(on: req.db)
                        .map { subtitle }
                }
        }

        project.delete(":id") { (req: Request) -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user.$projects
                .query(on: req.db)
                .filter(\.$id == id)
                .with(\.$translations)
                .with(\.$fragments) {
                    $0.with(\.$subtitles)
                }
                .with(\.$invites)
                .with(\.$shares)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .flatMap { project in
                    project.fragments.flatMap { $0.subtitles }
                        .delete(on: req.db)
                        .flatMap {
                            project.fragments.delete(on: req.db)
                        }
                        .flatMap {
                            project.translations.delete(on: req.db)
                        }
                        .flatMap {
                            project.invites.delete(on: req.db)
                        }
                        .flatMap {
                            project.shares.delete(on: req.db)
                        }
                        .flatMap {
                            project.delete(on: req.db)
                        }
                }
                .map { "Project deleted." }
        }
    }

}
