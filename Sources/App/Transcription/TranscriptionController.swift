import Fluent
import Vapor

extension EventLoopFuture {

    func guardRead(keyPath: KeyPath<Value, Project>, req: Request) -> EventLoopFuture<Value> {
        throwingFlatMap { value in
            TranscriptionController.verifyRead(req: req, for: value[keyPath: keyPath])
                .guard({ $0 }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .map { _ in value }
        }
    }

    func guardWrite(keyPath: KeyPath<Value, Project>, req: Request) -> EventLoopFuture<Value> {
        throwingFlatMap { value in
            TranscriptionController.verifyWrite(req: req, for: value[keyPath: keyPath])
                .guard({ $0 }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .map { _ in value }
        }
    }

}

extension EventLoopFuture where Value == Project {

    func guardRead(req: Request) -> EventLoopFuture<Project> {
        throwingFlatMap { project in
            TranscriptionController.verifyRead(req: req, for: project)
                .guard({ $0 }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .map { _ in project }
        }
    }

    func guardWrite(req: Request) -> EventLoopFuture<Project> {
        throwingFlatMap { project in
            TranscriptionController.verifyWrite(req: req, for: project)
                .guard({ $0 }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .map { _ in project }
        }
    }

}

struct SubtitleWord {
    let text: String
    let time: VTTFileRoot.Subtitle.TimeRange
}

struct SubtitleCharacter {
    let character: Character
    let time: VTTFileRoot.Subtitle.TimeRange
}

class TranscriptionController: RouteCollection {

    var projectSessions = [UUID: ProjectSession]()

    static func verifyRead(req: Request, for project: Project) -> EventLoopFuture<Bool> {
        if let encodedShareHash = try? req.headers.first(name: "X-Kotu-Share-Hash") ?? req.query.get(at: "shareHash"), encodedShareHash.count > 0, let projectID = try? project.requireID(), let data = Data(base64Encoded: encodedShareHash) {
            let key = SymmetricKey(data: project.owner.passwordHash.data(using: .utf8)!)
            let readOnly = "\(projectID)-readonly".data(using: .utf8)!
            let edit = "\(projectID)-edit".data(using: .utf8)!
            let result = HMAC<SHA256>.isValidAuthenticationCode(data, authenticating: readOnly, using: key) || HMAC<SHA256>.isValidAuthenticationCode(data, authenticating: edit, using: key)
            return req.eventLoop.future(result: .success(result))
        }

        if let user = req.auth.get(User.self) {
            if project.owner.id == user.id {
                return req.eventLoop.future(result: .success(true))
            }

            return user.$shares
                .query(on: req.db)
                .with(\.$project) {
                    $0.with(\.$owner)
                }
                .all()
                .map { $0.contains { $0.project.id == project.id || ($0.project.owner.id == project.owner.id && $0.shareAllProjects) }}
        }
        return req.eventLoop.future(result: .success(false))
    }

    static func verifyWrite(req: Request, for project: Project) -> EventLoopFuture<Bool> {
        if let encodedShareHash = try? req.headers.first(name: "X-Kotu-Share-Hash") ?? req.query.get(at: "shareHash"), encodedShareHash.count > 0, let projectID = try? project.requireID(), let data = Data(base64Encoded: encodedShareHash) {
            let key = SymmetricKey(data: project.owner.passwordHash.data(using: .utf8)!)
            let edit = "\(projectID)-edit".data(using: .utf8)!
            let result = HMAC<SHA256>.isValidAuthenticationCode(data, authenticating: edit, using: key)
            return req.eventLoop.future(result: .success(result))
        }

        if let user = req.auth.get(User.self) {
            if project.owner.id == user.id {
                return req.eventLoop.future(result: .success(true))
            }

            return user.$shares
                .query(on: req.db)
                .with(\.$project) {
                    $0.with(\.$owner)
                }
                .all()
                .map { $0.contains { $0.project.id == project.id || ($0.project.owner.id == project.owner.id && $0.shareAllProjects) }}
        }
        return req.eventLoop.future(result: .success(false))
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
                .flatMap { ownedProjects -> EventLoopFuture<[Project]> in
                    user.$shares.query(on: req.db)
                        .with(\.$project) { projects in
                            projects.with(\.$translations) { translations in
                                translations.with(\.$language)
                            }
                            .with(\.$owner) { owner in
                                owner.with(\.$projects) { projects2 in
                                    projects2.with(\.$translations) { translations2 in
                                        translations2.with(\.$language)
                                    }
                                }
                            }
                        }
                        .all()
                        .map { (shares: [Share]) -> [Project] in
                            shares.filter { $0.shareAllProjects }
                                .flatMap { $0.project.owner.projects }
                            + shares.map { $0.project }
                        }
                        .map { sharedProjects -> [Project] in Array(Set(sharedProjects + ownedProjects)) }
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
                .guardRead(req: req)
        }

        project.get(":id", "translation", ":translationID", "download", ":kind") { (req: Request) -> EventLoopFuture<Response> in
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
                .guardRead(req: req)
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

        func downloadSubtitles(uuid: String, youtubeID: String, directory: URL, auto: Bool) throws {
            let task = Process()
            task.currentDirectoryURL = directory
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")

            var env = task.environment ?? [:]
            env["PATH"] = "/usr/bin:/usr/local/bin:/opt/homebrew/bin"
            task.environment = env

            task.arguments = [
                "youtube-dl",
                "-q",
                (auto ? "--write-auto-sub" : "--write-sub"),
                "--sub-lang", "ja",
                "--sub-format", "vtt",
                "--skip-download",
                "-o", "\(uuid)",
                "--write-info-json",
                "--no-warnings",
                "https://youtu.be/\(youtubeID)"
            ]
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                throw Abort(.internalServerError)
            }
        }

        project.post(":id", "autoSync") { (req: Request) -> EventLoopFuture<Response> in
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            struct Body: Content {
                let text: String
            }
            let originalText = try req.content.decode(Body.self).text

            // In the future do a join for shared projects.
            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .with(\.$translations) { translation in
                    translation.with(\.$language)
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guardWrite(req: req)
                .throwingFlatMap { project in
                    let directory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Temp")
                    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let uuid = UUID().uuidString

                    try downloadSubtitles(uuid: uuid, youtubeID: project.youtubeID, directory: directory, auto: true)
                    let fileURL = directory.appendingPathComponent(uuid).appendingPathExtension("ja.vtt")
                    guard let subtitleRoot = try SubtitleFile(file: fileURL, encoding: .utf8, kind: .vtt).root as? VTTFileRoot else {
                        try FileManager.default.removeItem(at: fileURL)
                        throw Abort(.internalServerError)
                    }

                    guard let translation = project.translations.first(where: { $0.isOriginal }) else {
                        throw Abort(.badRequest)
                    }
                    let subtitles = subtitleRoot.subtitles
                    let individualWords = subtitles.concurrentMap { subtitle -> [SubtitleWord] in
                        var words = [SubtitleWord]()
                        do {
                            let tokenizer = Tokenizer(input: subtitle.text)
                            tokenizer.consume(upUntil: "\n")
                            try tokenizer.consume(expect: "\n")
                            var start = subtitle.timeRange.start
                            var isFirst = true
                            while (isFirst || tokenizer.hasPrefix("<")) && !tokenizer.reachedEnd {
                                let text: String
                                if !isFirst {
                                    try tokenizer.consume(expect: "<c>")
                                    text = tokenizer.consume(upUntil: "<")
                                    try tokenizer.consume(expect: "</c>")
                                } else {
                                    text = tokenizer.consume(upUntil: "<")
                                }
                                let end: VTTFileRoot.Subtitle.TimeRange.Time
                                if tokenizer.hasPrefix("<") {
                                    try tokenizer.consume(expect: "<")
                                    end = try VTTFileRoot.Subtitle.TimeRange.Time.parse(tokenizer: tokenizer)

                                    try tokenizer.consume(expect: ">")
                                } else {
                                    end = subtitle.timeRange.end
                                }
                                words.append(.init(text: text, time: .init(start: start, end: end)))
                                start = end
                                isFirst = false
                            }
                        } catch { }
                        return words
                    }.flatMap { $0 }

                    let individualCharacters = individualWords.flatMap { word in
                        Array(word.text).map { SubtitleCharacter(character: $0, time: word.time)}
                    }
                    let alignment = try NeedlemanWunsch.align(input1: Array(originalText), input2: individualCharacters.concurrentMap { $0.character })
                    let originalAlignedCharacters = alignment.output1.enumerated().splitSeparator(separatorDecision: {
                        if case let .indexAndValue(_, char) = $0.element {
                            switch char {
                            case "\r\n", "\r", "\n", "\"", "「", "」": return .remove
                            case "。", ".", "？", "?": return .keepLeft
                            default: return .notSeparator
                            }
                        }
                        return .notSeparator
                    })
                    .filter { !$0.isEmpty }

                    let alignedSubtitles = originalAlignedCharacters.compactMap { characters -> MediaSubtitle? in
                        let text = String(characters.compactMap { match -> Character? in
                            if case let .indexAndValue(_, value) = match.element {
                                return value
                            }
                            return nil
                        }).trimmingCharacters(in: .whitespacesAndNewlines)

                        if text.isEmpty {
                            return nil
                        }

                        let startIndex = characters.first!.offset
                        let endIndex = characters.last!.offset
                        let searchArea = alignment.output2[startIndex...endIndex]

                        let optionalStartMatch = searchArea.first(where: {
                            if case .indexAndValue(_, _) = $0 {
                                return true
                            }
                            return false
                        })
                        guard case let .indexAndValue(matchStartIndex, _) = optionalStartMatch else {
                            return nil
                        }

                        let optionalEndMatch = searchArea.last(where: {
                            if case .indexAndValue(_, _) = $0 {
                                return true
                            }
                            return false
                        })
                        guard case let .indexAndValue(matchEndIndex, _) = optionalEndMatch else {
                            return nil
                        }

                        let startTime = individualCharacters[matchStartIndex].time.start.milliseconds / 1000
                        let endTime = individualCharacters[matchEndIndex].time.end.milliseconds / 1000

                        return MediaSubtitle(startTime: startTime, endTime: endTime, text: text)
                    }

                    let chunks = try alignedSubtitles.chunked(into: 127).map { chunk ->  EventLoopFuture<Void> in
                        let futures = try chunk.map { subtitle -> EventLoopFuture<Void> in
                            let fragment = Fragment(projectID: try project.requireID(), startTime: subtitle.startTime, endTime: subtitle.endTime)
                            return fragment.create(on: req.db)
                                .throwingFlatMap {
                                    Subtitle(translationID: try translation.requireID(), fragmentID: try fragment.requireID(), text: subtitle.text)
                                        .create(on: req.db)
                                }
                        }
                        return EventLoopFuture.whenAllSucceed(futures, on: req.eventLoop).map { _ in () }
                    }

                    return EventLoopFuture.reduce((), chunks, on: req.eventLoop) { _,_  in () }
                        .map { _ in Response(status: .ok) }
                }
        }

        func saveSection(application: Application, file: URL, start: Double, end: Double) throws -> URL {
            let directory = URL(fileURLWithPath: application.directory.resourcesDirectory).appendingPathComponent("Temp")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let uuid = UUID().uuidString

            let task = Process()
            task.currentDirectoryURL = directory
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")

            var env = task.environment ?? [:]
            env["PATH"] = "/usr/bin:/usr/local/bin:/opt/homebrew/bin"
            task.environment = env

            task.arguments = [
                "ffmpeg",
                "-ss", start.toString(),
                "-to", end.toString(),
                "-i", file.path,
                "\(uuid).\(file.pathExtension)"
            ]
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                throw Abort(.internalServerError)
            }

            return directory.appendingPathComponent(uuid).appendingPathExtension(file.pathExtension)
        }

        project.grouped(GuardPermissionMiddleware(require: .subtitles)).post(":id", "systemImport") { (req: Request) -> EventLoopFuture<Response> in
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            struct Body: Content {
                let isAudiobook: Bool
            }
            let object = try req.content.decode(Body.self)
            let tags: [String] = [
                object.isAudiobook ? "audiobook" : nil
            ]
            .compactMap { $0 }

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
                .guardRead(req: req)
                .throwingFlatMap { project in
                    guard let translation = project.translations.first(where: { $0.isOriginal }) else {
                        throw Abort(.badRequest)
                    }
                    
                    let subtitles = project.fragments.flatMap { $0.subtitles.filter { $0.translation.id == translation.id } }
                        .filter { $0.fragment.startTime < $0.fragment.endTime }
                        .sorted(by: { $0.fragment.startTime < $1.fragment.startTime })

                    let directory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Temp")
                    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

                    let externalFilesDirectory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Files")
                    try? FileManager.default.createDirectory(at: externalFilesDirectory, withIntermediateDirectories: true)

                    let uuid = UUID().uuidString

                    let task = Process()
                    task.currentDirectoryURL = directory
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")

                    var env = task.environment ?? [:]
                    env["PATH"] = "/usr/bin:/usr/local/bin:/opt/homebrew/bin"
                    task.environment = env

                    task.arguments = [
                        "youtube-dl",
                        "-q",
                        "--extract-audio",
                        "--audio-format", "m4a",
                        "--audio-quality", "0",
                        "-o", "\(uuid).%(ext)s",
                        "https://youtu.be/\(project.youtubeID)"
                    ]
                    try task.run()
                    task.waitUntilExit()
                    if task.terminationStatus != 0 {
                        throw Abort(.internalServerError)
                    }

                    let fileURL = directory.appendingPathComponent(uuid).appendingPathExtension("m4a")

                    let savedFiles = try subtitles.map {
                        try saveSection(application: req.application, file: fileURL, start: $0.fragment.startTime, end: $0.fragment.endTime)
                    }

                    let video = AnkiDeckVideo(title: project.name, source: "youtube", tags: tags)
                    return video.create(on: req.db).throwingFlatMap {
                        let chunks = try Array(subtitles.enumerated()).chunked(into: 127).map { chunk ->  EventLoopFuture<Void> in
                            let futures = try chunk.map { (index, subtitle) -> EventLoopFuture<Void> in
                                let filePath = savedFiles[index]
                                let fileSize: UInt64
                                let attr = try FileManager.default.attributesOfItem(atPath: filePath.path)
                                let ext = filePath.pathExtension
                                fileSize = attr[FileAttributeKey.size] as! UInt64
                                let externalFile = ExternalFile(size: Int(fileSize), path: "", ext: ext)
                                return externalFile
                                    .create(on: req.db)
                                    .throwingFlatMap {
                                        let uuid = try externalFile.requireID().uuidString
                                        let newFilePath = externalFilesDirectory.appendingPathComponent("\(uuid).\(ext)")
                                        externalFile.path = newFilePath.pathComponents.last!
                                        try FileManager.default.moveItem(at: filePath, to: newFilePath)
                                        return externalFile.update(on: req.db)
                                    }
                                    .flatMap {
                                        AnkiDeckSubtitle(video: video, text: subtitle.text, externalFile: externalFile, startTime: subtitle.fragment.startTime, endTime: subtitle.fragment.endTime)
                                            .create(on: req.db)
                                    }
                            }

                            return EventLoopFuture.whenAllSucceed(futures, on: req.eventLoop).map { _ in () }
                        }
                        return EventLoopFuture.reduce((), chunks, on: req.eventLoop) { _,_  in () }
                            .map { _ in Response(status: .ok) }
                    }
                }
        }

        // MARK: Socket

        project.webSocket(":id", "socket") { (req: Request, ws: WebSocket) in
            let user = req.auth.get(User.self) ?? User.guest
            guard let projectID = req.parameters.get("id", as: UUID.self) else {
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
                .guardRead(req: req)
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
            projectCall
                .flatMap { project in
                    Self.verifyWrite(req: req, for: project)
                        .map { (project, $0) }
                }
                .whenSuccess({ [unowned self] (project, canWrite) in
                    guard let session = self.session(for: project) else {
                        return ws.close(promise: nil)
                    }

                    let wsID = UUID().uuidString
                    let existingColors = session.existingColors
                    let randomColors = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal", "cyan"]
                    let onceRandomColors = randomColors.filter { !existingColors.contains($0) }
                    let color = onceRandomColors.randomElement() ?? randomColors.randomElement()!
                    let hello = Hello(id: wsID, color: color, canWrite: canWrite, project: project, messages: session.messages)
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
            guard let projectID = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "Project ID not provided") }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .filter(\.$id == projectID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guardWrite(req: req)
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

            try Invite.Create.validate(content: req)
            let object = try req.content.decode(Invite.Create.self)
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

                            let invite = Invite(projectID: projectID, inviteeID: inviteeID, shareAllProjects: object.shareAllProjects)
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
                            let share = Share(projectID: projectID, sharedUserID: userID, shareAllProjects: invite.shareAllProjects)
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
                .guardWrite(req: req)
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
                .guardWrite(req: req)
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

        project.put(":id", "fragment", ":fragmentID") { (req: Request) -> EventLoopFuture<Fragment> in
            guard let projectID = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let fragmentID = req.parameters.get("fragmentID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try Fragment.Put.validate(content: req)
            let object = try req.content.decode(Fragment.Put.self)
            guard object.startTime <= object.endTime else {
                throw Abort(.badRequest, reason: "Start time can not be greater than end time")
            }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$fragments) {
                    $0.with(\.$subtitles) { subtitle in
                        subtitle.with(\.$translation)
                    }
                }
                .with(\.$shares) {
                    $0.with(\.$sharedUser)
                }
                .filter(\.$id == projectID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guardWrite(req: req)
                .throwingFlatMap { project in
                    guard let fragment = project.fragments.first(where: { $0.id == fragmentID }) else {
                        throw Abort(.notFound)
                    }
                    fragment.startTime = object.startTime
                    fragment.endTime = object.endTime
                    return fragment.save(on: req.db)
                        .map {
                            guard let session = self.projectSessions[projectID] else {
                                return fragment
                            }

                            session.sendFragment(fragment: fragment)
                            return fragment
                        }
                }
        }

        project.delete(":id", "fragment", ":fragmentID") { (req: Request) -> EventLoopFuture<Response> in
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
                .guardWrite(req: req)
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
                .guardWrite(req: req)
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
                .guardWrite(keyPath: \.fragment.project, req: req)
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
