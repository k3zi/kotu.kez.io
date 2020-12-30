import Fluent
import Vapor

class TranscriptionController: RouteCollection {

    var projectSessions = [UUID: ProjectSession]()

    static func verifyRead(req: Request, for project: Project) -> Bool {
        guard let encodedShareHash = try? req.headers.first(name: "X-Kotu-Share-Hash") ?? req.query.get(at: "shareHash"), let projectID = try? project.requireID() else {
            return false
        }
        guard let data = Data(base64Encoded: encodedShareHash) else {
            return false
        }
        let key = SymmetricKey(data: project.owner.passwordHash.data(using: .utf8)!)
        let readOnly = "\(projectID)-readonly".data(using: .utf8)!
        let edit = "\(projectID)-edit".data(using: .utf8)!
        return HMAC<SHA256>.isValidAuthenticationCode(data, authenticating: readOnly, using: key) || HMAC<SHA256>.isValidAuthenticationCode(data, authenticating: edit, using: key)
    }

    static func verifyWrite(req: Request, for project: Project) -> Bool {
        guard let encodedShareHash = try? req.headers.first(name: "X-Kotu-Share-Hash") ?? req.query.get(at: "shareHash"), let projectID = try? project.requireID() else {
            return false
        }
        guard let data = Data(base64Encoded: encodedShareHash) else {
            return false
        }
        let key = SymmetricKey(data: project.owner.passwordHash.data(using: .utf8)!)
        let edit = "\(projectID)-edit".data(using: .utf8)!
        return HMAC<SHA256>.isValidAuthenticationCode(data, authenticating: edit, using: key)
    }

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

        let guardedTranscriptions = transcription
            .grouped(User.guardMiddleware())

        guardedTranscriptions.get("invites") { req -> EventLoopFuture<[Invite]> in
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

        let protectedProjects = guardedTranscriptions.grouped("projects")

        protectedProjects.get { req -> EventLoopFuture<[Project]> in
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

        let protectedProject = guardedTranscriptions.grouped("project")
        let project = transcription.grouped("project")
        protectedProject.post("create") { req -> EventLoopFuture<Project> in
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
            let user = req.auth.get(User.self) ?? User.guest
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
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyRead(req: req, for: $0) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
        }

        project.get(":id", "translation", ":translationID", "download", ":kind") { (req: Request) -> EventLoopFuture<Response> in
            let user = req.auth.get(User.self) ?? User.guest
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let translationID = req.parameters.get("translationID", as: UUID.self) else { throw Abort(.badRequest, reason: "Translation not provided") }
            guard let kind = req.parameters.get("kind", as: SubtitleFile.Kind.self) else { throw Abort(.badRequest, reason: "Subtitle kind not provided") }

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
                        subtitle
                            .with(\.$translation)
                            .with(\.$fragment)
                    }
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyRead(req: req, for: $0) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .flatMapThrowing { project in
                    let subtitles = project.fragments.flatMap { $0.subtitles.filter { $0.translation.id == translationID } }.sorted(by: { $0.fragment.startTime < $1.fragment.startTime })
                    let language = project.translations.first { $0.id == translationID }?.language
                    let genericSubtitles = subtitles.map {
                        GenericSubtitleFile.Subtitle(text: $0.text, start: $0.fragment.startTime, end: $0.fragment.endTime)
                    }
                    let genericSubtitleFile = GenericSubtitleFile(subtitles: genericSubtitles)
                    let file = try SubtitleFile(file: genericSubtitleFile, kind: kind)
                    let string = file.asString()
                    guard let data = string.data(using: .utf8) else {
                        throw Abort(.internalServerError)
                    }

                    let response = Response(status: .ok)
                    if let type = HTTPMediaType.fileExtension(kind.fileExtension) {
                        response.headers.contentType = type
                    }
                    let filename = [project.name, language?.code, kind.fileExtension]
                        .compactMap { $0 }.filter { $0.count > 0 }.joined(separator: ".")
                    response.headers.contentDisposition = .init(.attachment, filename: filename)
                    response.body = .init(data: data)
                    return response
                }
        }

        // MARK: Socket

        project.webSocket(":id", "socket") { (req: Request, ws: WebSocket) in
            let user = req.auth.get(User.self) ?? User.guest
            guard let userID = try? user.requireID(), let projectID = req.parameters.get("id", as: UUID.self) else {
                return ws.close(promise: nil)
            }

            let projectCall = Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .with(\.$translations) { translation in
                    translation.with(\.$language)
                }
                .with(\.$fragments) { fragments in
                    fragments.with(\.$subtitles) { subtitle in
                        subtitle
                            .with(\.$translation)
                            .with(\.$fragment)
                    }
                }
                .filter(\.$id == projectID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyRead(req: req, for: $0) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .flatMap { project -> EventLoopFuture<Project> in
                    let allSubtitles = project.fragments.flatMap { $0.subtitles }
                    let duplicates = allSubtitles
                        .filter { sub in sub.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .filter { sub in allSubtitles.contains { $0.fragment.id == sub.fragment.id && $0.translation.id == sub.translation.id && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
                    return duplicates.delete(on: req.db)
                        .flatMap {
                            project.$fragments.query(on: req.db)
                                .with(\.$subtitles) { subtitle in
                                    subtitle
                                        .with(\.$translation)
                                        .with(\.$fragment)
                                }
                                .all()
                                .map {
                                    project.$fragments.value = $0
                                    return project
                                }
                        }
                }

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
                let hello = Hello(id: wsID, color: color, canWrite: project.owner.id == userID || project.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyWrite(req: req, for: project), project: project)
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

        // MARK: Sharing

        project.get(":id", "shareURLs") { (req: Request) -> EventLoopFuture<Project.ShareHash> in
            let user = req.auth.get(User.self) ?? User.guest
            let userID = try user.requireID()
            guard let projectID = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "Project ID not provided") }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .filter(\.$id == projectID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyWrite(req: req, for: $0) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .flatMapThrowing { project in
                    let key = SymmetricKey(data: project.owner.passwordHash.data(using: .utf8)!)
                    let readOnly = "\(projectID)-readonly".data(using: .utf8)!
                    let readOnlyEncrypted = Data(HMAC<SHA256>.authenticationCode(for: readOnly, using: key)).base64EncodedString()

                    let edit = "\(projectID)-edit".data(using: .utf8)!
                    let editEncrypted = Data(HMAC<SHA256>.authenticationCode(for: edit, using: key)).base64EncodedString()
                    return Project.ShareHash(readOnly: readOnlyEncrypted, edit: editEncrypted)
                }
        }


        // MARK: Invites

        protectedProject.post(":id", "invite", ":username") { (req: Request) -> EventLoopFuture<Invite> in
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

        protectedProject.post(":id", "invite", "accept") { (req: Request) -> EventLoopFuture<Share> in
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

        protectedProject.post(":id", "invite", "decline") { (req: Request) -> EventLoopFuture<Response> in
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
            let user = req.auth.get(User.self) ?? User.guest
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
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyWrite(req: req, for: $0) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
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
            let user = req.auth.get(User.self) ?? User.guest
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
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyWrite(req: req, for: $0) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
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
            let user = req.auth.get(User.self) ?? User.guest
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
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyWrite(req: req, for: $0) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
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
            let user = req.auth.get(User.self) ?? User.guest
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
                .guard({ $0.owner.id == userID || $0.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyWrite(req: req, for: $0) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .throwingFlatMap { project in
                    guard let translation = project.translations.first(where: { $0.id == object.translationID }) else {
                        throw Abort(.badRequest, reason: "Translation could not be found")
                    }

                    guard let fragment = project.fragments.first(where: { $0.id == object.fragmentID }) else {
                        throw Abort(.badRequest, reason: "Fragment could not be found")
                    }

                    guard !fragment.subtitles.contains(where: { $0.translation.id == translation.id }) else {
                        throw Abort(.badRequest, reason: "Duplicate subtitle found")
                    }

                    let subtitle = Subtitle(translationID: try translation.requireID(), fragmentID: try fragment.requireID(), text: object.text)
                    return subtitle.save(on: req.db)
                        .map { subtitle }
                }
        }

        project.put(":id", "subtitle", ":subtitleID") { (req: Request) -> EventLoopFuture<Subtitle> in
            let user = req.auth.get(User.self) ?? User.guest
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
                .guard({ $0.fragment.project.owner.id == userID || $0.fragment.project.shares.contains(where: { $0.sharedUser.id == userID }) || Self.verifyWrite(req: req, for: $0.fragment.project) }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .guard({ $0.fragment.project.id == id }, else: Abort(.unauthorized, reason: "Subtitle does not belong to this project"))
                .flatMap { subtitle in
                    subtitle.text = object.text
                    return subtitle.update(on: req.db)
                        .map { subtitle }
                }
        }

        protectedProject.delete(":id") { (req: Request) -> EventLoopFuture<String> in
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
