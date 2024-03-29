import Fluent
import IkigaJSON
import Vapor

struct MediaCaptureRequest: Content {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let youtubeID: String
}

struct MediaSubtitle: Content {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

struct MediaYouTubeInfo: Decodable {
    struct Thumbnail: Decodable {
        let url: URL
    }
    let title: String
    let thumbnails: [Thumbnail]
}

extension MediaCaptureRequest: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("startTime", as: Double.self)
        validations.add("endTime", as: Double.self)
        validations.add("youtubeID", as: String.self, is: !.empty)
    }

}

struct PlexCaptureRequest: Content {
    let startTime: TimeInterval
    let endTime: TimeInterval
}

extension PlexCaptureRequest: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("startTime", as: Double.self)
        validations.add("endTime", as: Double.self)
    }

}

extension Page {

    /// Maps a page's items to a different type using the supplied closure.
    public func flatMap<U>(_ transform: (T) throws -> ([U])) rethrows -> Page<U> where U: Codable {
        try .init(
            items: self.items.flatMap(transform),
            metadata: self.metadata
        )
    }

}

class MediaController: RouteCollection {

    static func stringFromTimeInterval(interval: TimeInterval) -> String {
        let allSeconds = Int(interval)
        let milliseconds = Int((interval * 1000)) % 1000
        let seconds = allSeconds % 60
        let minutes = (allSeconds / 60) % 60
        let hours = (allSeconds / 3600)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }

    func boot(routes: RoutesBuilder) throws {
        let media = routes.grouped("media")

        let guardedMedia = media
            .grouped(User.guardMiddleware())

        media.get("nhk", "audio", ":file") { req -> Response in
            guard let file = req.parameters.get("file", as: String.self), !file.contains(where: { !$0.isASCII || $0.isNewline || $0 == "/" || $0 == "\\" }) else { throw Abort(.badRequest, reason: "File not provided") }
            let directory = req.application.directory.workingDirectory
            let directoryURL = URL(fileURLWithPath: directory)
            let fileURL = directoryURL
                .appendingPathComponent("../Dictionaries/NHK_ACCENT/extracted_audio")
                .appendingPathComponent(file)
            let data = try Data(contentsOf: fileURL)
            let rangeString = req.headers.first(name: .range) ?? ""
            let response = Response(status: .ok)
            response.headers.contentType = HTTPMediaType.audio
            response.headers.contentDisposition = .init(.attachment, filename: file)
            if rangeString.count > 0 {
                let range = try Range.parse(tokenizer: .init(input: rangeString))
                let croppedData = data[range.startByte...min(range.endByte, data.endIndex - 1)]
                response.headers.remove(name: .contentLength)
                response.headers.add(name: .contentRange, value: "bytes \(croppedData.startIndex)-\(croppedData.endIndex)/\(data.count)")
                response.headers.add(name: .contentLength, value: String(croppedData.count))
                response.body = .init(data: croppedData)
            } else {
                response.body = .init(data: data)
            }
            return response
        }

        func output(data fileData: Data, filename: String, mediaType: HTTPMediaType? = nil, for req: Request) throws -> Response {
            let rangeString = req.headers.first(name: .range) ?? ""
            let response = Response(status: .ok)
            response.headers.contentType = mediaType
            response.headers.contentDisposition = .init(.attachment, filename: filename)
            if rangeString.count > 0 {
                let range = try Range.parse(tokenizer: .init(input: rangeString))
                let data = fileData[range.startByte...min(range.endByte, fileData.endIndex - 1)]
                response.headers.add(name: .contentRange, value: "bytes \(data.startIndex)-\(data.endIndex)/\(fileData.count)")
                response.headers.add(name: .contentLength, value: String(data.count))
                response.body = .init(data: data)
            } else {
                response.body = .init(data: fileData)
            }
            return response
        }

        func fileResponse(for req: Request) throws -> EventLoopFuture<Response> {
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return ExternalFile
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .throwingFlatMap { file in
                    guard let file = file else {
                        return File
                            .query(on: req.db)
                            .filter(\.$id == id)
                            .first()
                            .unwrap(orError: Abort(.notFound))
                            .flatMapThrowing { file in
                                let filename = "\(file.id!.uuidString).m4a"
                                return try output(data: file.data, filename: filename, mediaType: HTTPMediaType.audio, for: req)
                            }
                    }
                    let fileURL = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Files").appendingPathComponent(file.path)
                    var mediaType: HTTPMediaType?
                    if file.path.hasSuffix(".m4a") {
                        mediaType = .init(type: "audio", subType: "x-m4a")
                    }
                    let fileExtension = fileURL.pathExtension
                    let type = mediaType ?? HTTPMediaType.fileExtension(fileExtension)

                    let fileData = try Data(contentsOf: fileURL)
                    let response = try output(data: fileData, filename: fileURL.pathComponents.last!, mediaType: type, for: req)
                    return req.eventLoop.future(response)
                }
        }

        media.get("external", "audio", ":id") { req -> EventLoopFuture<Response> in
            try fileResponse(for: req)
        }

        media.get("audio", ":id") { req -> EventLoopFuture<Response> in
            try fileResponse(for: req)
        }

        let anki = guardedMedia.grouped("anki")
        anki.get("subtitles", "search") { req -> EventLoopFuture<Page<AnkiDeckSubtitle>> in
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }

            let tags: [String] = [
                ((try? req.query.get(Bool.self, at: "audiobook")) ?? false) ? "audiobook" : nil
            ].compactMap { $0 }
            var query = AnkiDeckSubtitle.query(on: req.db)
                .join(parent: \.$video)
            if !tags.isEmpty {
                query = query.filter(AnkiDeckVideo.self, \.$tags, .custom("@>"), tags)
            }

            if q.contains("|") {
                let modifiedQuery = q.components(separatedBy: "|").filter { !$0.isEmpty }
                query = query.group(.or) {
                    $0.filter(all: modifiedQuery) { text in
                        \.$text ~~ text
                    }
                }
            } else {
                var modifiedQuery = q.replacingOccurrences(of: "?", with: "_").replacingOccurrences(of: "*", with: "%")
                modifiedQuery = "%\(modifiedQuery)%"
                query = query
                    .filter(\.$text, .custom("ILIKE"), modifiedQuery)
            }

            return query
                .with(\.$video)
                .sort(\.$id)
                .paginate(for: req)
        }

        anki.get("media", "search") { req -> EventLoopFuture<[AnkiDeckVideo]> in
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            return AnkiDeckVideo
                .query(on: req.db)
                .filter(\.$title ~~ q)
                .limit(15)
                .all()
        }

//        anki.get("subtitles", ":id", "all") { req -> EventLoopFuture<AnkiDeckVideo> in
//            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
//            return AnkiDeckVideo.query(on: req.db)
//                .filter(\.$id == id)
//                .with(\.$subtitles)
//                .first()
//                .unwrap(or: Abort(.notFound))
//        }

        let youtube = guardedMedia.grouped("youtube")

        youtube.post("capture") { req -> EventLoopFuture<ExternalFile> in
            try MediaCaptureRequest.validate(content: req)
            let object = try req.content.decode(MediaCaptureRequest.self)

            let directory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Temp")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
                "--postprocessor-args",
                "-ss \(Self.stringFromTimeInterval(interval: object.startTime)) -to \(Self.stringFromTimeInterval(interval: object.endTime))",
                "--extract-audio",
                "--audio-format", "m4a",
                "--audio-quality", "0",
                "-o", "\(uuid).%(ext)s",
                "https://youtu.be/\(object.youtubeID)"
            ]
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                throw Abort(.internalServerError)
            }

            let fileURL = directory.appendingPathComponent(uuid).appendingPathExtension("m4a")
            let data = try Data(contentsOf: fileURL)
            try FileManager.default.removeItem(at: fileURL)

            let externalFile = ExternalFile(size: Int(data.count), path: "", aliasPath: nil, ext: "m4a")
            return externalFile
                .create(on: req.db)
                .throwingFlatMap {
                    let externalFilesDirectory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Files")
                    let uuid = try externalFile.requireID().uuidString
                    let newFilePath = externalFilesDirectory.appendingPathComponent("\(uuid).m4a")
                    externalFile.path = newFilePath.pathComponents.last!
                    try data.write(to: newFilePath)
                    return externalFile.update(on: req.db)
                }.map { externalFile }
        }

        youtube.get("download") { req -> Response in
            let startTime = try req.query.get(TimeInterval.self, at: "startTime")
            let endTime = try req.query.get(TimeInterval.self, at: "endTime")
            let youtubeID = try req.query.get(String.self, at: "youtubeID")
            let object = MediaCaptureRequest(startTime: startTime, endTime: endTime, youtubeID: youtubeID)
            let directory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Temp")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
                "--postprocessor-args",
                "-ss \(Self.stringFromTimeInterval(interval: object.startTime)) -to \(Self.stringFromTimeInterval(interval: object.endTime))",
                "--extract-audio",
                "--audio-format", "m4a",
                "--audio-quality", "0",
                "-o", "\(uuid).%(ext)s",
                "https://youtu.be/\(object.youtubeID)"
            ]
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                throw Abort(.internalServerError)
            }

            let fileURL = directory.appendingPathComponent(uuid).appendingPathExtension("m4a")
            let data = try Data(contentsOf: fileURL)
            try FileManager.default.removeItem(at: fileURL)

            let rangeString = req.headers.first(name: .range) ?? ""
            let response = Response(status: .ok)
            response.headers.contentType = HTTPMediaType.audio
            let filename = "\(uuid).m4a"
            response.headers.contentDisposition = .init(.attachment, filename: filename)
            if rangeString.count > 0 {
                let range = try Range.parse(tokenizer: .init(input: rangeString))
                let partialData = data[range.startByte...min(range.endByte, data.endIndex - 1)]
                response.headers.add(name: .contentRange, value: "bytes \(partialData.startIndex)-\(partialData.endIndex)/\(data.count)")
                response.headers.add(name: .contentLength, value: String(partialData.count))
                response.body = .init(data: partialData)
            } else {
                response.body = .init(data: data)
            }
            return response
        }

        youtube.get("subtitles", "search") { req -> EventLoopFuture<Page<YouTubeSubtitle>> in
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            var modifiedQuery = q.replacingOccurrences(of: "?", with: "_").replacingOccurrences(of: "*", with: "%")
            modifiedQuery = "%\(modifiedQuery)%"
            return YouTubeSubtitle.query(on: req.db)
                .filter(\.$text, .custom("LIKE"), modifiedQuery)
                .with(\.$youtubeVideo)
                .sort(\.$startTime)
                .paginate(for: req)
        }

        youtube.get("subtitles", ":youtubeID") { req -> EventLoopFuture<[MediaSubtitle]> in
            let youtubeID = try req.parameters.require("youtubeID")
            let onlyManual = (try? req.query.get(Bool.self, at: "onlyManual")) ?? false
            return YouTubeVideo.query(on: req.db)
                .filter(\.$youtubeID == youtubeID)
                .with(\.$subtitles)
                .first()
                .throwingFlatMap { video -> EventLoopFuture<[MediaSubtitle]> in
                    if let video = video, video.subtitles.count > 0 {
                        let subtitles = video.subtitles.map {
                            MediaSubtitle(startTime: $0.startTime, endTime: $0.endTime, text: $0.text)
                        }
                        return req.eventLoop.future(subtitles)
                    }

                    let directory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Temp")
                    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let uuid = UUID().uuidString

                    func downloadSubtitles(uuid: String, directory: URL, auto: Bool) throws {
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

                    var isAuto = false
                    try downloadSubtitles(uuid: uuid, directory: directory, auto: false)
                    let fileURL = directory.appendingPathComponent(uuid).appendingPathExtension("ja.vtt")
                    let infoURL = directory.appendingPathComponent(uuid).appendingPathExtension("info.json")
                    if !FileManager.default.fileExists(atPath: fileURL.path) {
                        if onlyManual {
                            return req.eventLoop.future([])
                        }
                        try downloadSubtitles(uuid: uuid, directory: directory, auto: true)
                        isAuto = true
                    }
                    guard let subtitleRoot = try SubtitleFile(file: fileURL, encoding: .utf8, kind: .vtt).root as? VTTFileRoot else {
                        try FileManager.default.removeItem(at: fileURL)
                        throw Abort(.internalServerError)
                    }
                    let infoData = try Data(contentsOf: infoURL)
                    let info = try JSONDecoder().decode(MediaYouTubeInfo.self, from: infoData)
                    try FileManager.default.removeItem(at: infoURL)
                    try FileManager.default.removeItem(at: fileURL)
                    let subtitles: [MediaSubtitle] = subtitleRoot.subtitles.map {
                        var text = (isAuto && $0.text.contains("<c>")) ? $0.text.components(separatedBy: "\n").suffix(from: 1).joined() : $0.text
                        text = text.replacingOccurrences(of: "<c>", with: "", options: .regularExpression)
                        text = text.replacingOccurrences(of: "</c>", with: "", options: .regularExpression)
                        text = text.replacingOccurrences(of: "<\\d+:\\d+:\\d+.\\d+>", with: "", options: .regularExpression)

                        return MediaSubtitle(startTime: Double($0.timeRange.start.milliseconds) / 1000, endTime: Double($0.timeRange.end.milliseconds) / 1000, text: text)
                    }

                    if isAuto {
                        return req.eventLoop.future(subtitles)
                    }

                    return YouTubeVideo.query(on: req.db)
                        .filter(\.$youtubeID == youtubeID)
                        .count()
                        .flatMap {
                            if $0 > 0 {
                                return req.eventLoop.future(subtitles)
                            }

                            let video = YouTubeVideo(youtubeID: youtubeID, title: info.title, thumbnailURL: info.thumbnails.suffix(2).first!.url.absoluteString)
                            return video.create(on: req.db)
                                .flatMap {
                                    subtitles.map {
                                        YouTubeSubtitle(youtubeVideo: video, text: $0.text, startTime: $0.startTime, endTime: $0.endTime)
                                    }.create(on: req.db)
                                }
                                .map { subtitles }
                        }
                }
        }

        let plex = guardedMedia.grouped("plex")

        plex.post("signIn") { req -> EventLoopFuture<PinRequest> in
            Plex().signIn(client: req.client)
        }

        plex.get("checkPin", ":id") { req -> EventLoopFuture<SignInResponse> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id", as: Int.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            return Plex().checkPin(client: req.client, id: id)
                .flatMap { signInResponse in
                    if signInResponse.linked != nil {
                        user.plexAuth = signInResponse
                        return user.save(on: req.db)
                            .map { signInResponse }
                    } else {
                        return req.eventLoop.future(signInResponse)
                    }
                }
        }

        plex.get("resources") { req -> EventLoopFuture<[Resource]> in
            let user = try req.auth.require(User.self)
            guard let token = user.plexAuth?.linked?.authToken else { throw Abort(.badRequest, reason: "User has no Plex account") }
            return Plex().resources(client: req.client, token: token)
        }

        plex.get("resource", ":clientIdentifier", "sections") { req -> EventLoopFuture<[Section]> in
            let user = try req.auth.require(User.self)
            guard let token = user.plexAuth?.linked?.authToken else { throw Abort(.badRequest, reason: "User has no Plex account") }
            guard let clientIdentifier = req.parameters.get("clientIdentifier", as: String.self) else { throw Abort(.badRequest, reason: "Client identifier not provided") }
            let plex = Plex()
            return plex.resources(client: req.client, token: token)
                .map { resources in
                    resources.first { $0.clientIdentifier == clientIdentifier }
                }
                .unwrap(orError: Abort(.badRequest, reason: "Resource not found"))
                .flatMap { resource in
                    plex.providers(client: req.client, resource: resource)
                }
        }

        plex.get("resource", ":clientIdentifier", "section", ":sectionPath") { req -> EventLoopFuture<[Metadata]> in
            let user = try req.auth.require(User.self)
            guard let token = user.plexAuth?.linked?.authToken else { throw Abort(.badRequest, reason: "User has no Plex account") }
            guard let clientIdentifier = req.parameters.get("clientIdentifier", as: String.self) else { throw Abort(.badRequest, reason: "Client identifier not provided") }
            guard let sectionPath = req.parameters.get("sectionPath", as: String.self) else { throw Abort(.badRequest, reason: "Section path not provided") }
            let plex = Plex()
            return plex.resources(client: req.client, token: token)
                .map { resources in
                    resources.first { $0.clientIdentifier == clientIdentifier }
                }
                .unwrap(orError: Abort(.badRequest, reason: "Resource not found"))
                .flatMap { resource in
                    plex.all(client: req.client, resource: resource, path: sectionPath)
                }
        }

        plex.get("resource", ":clientIdentifier", "stream", ":mediaID") { req -> EventLoopFuture<[String]> in
            let user = try req.auth.require(User.self)
            guard let token = user.plexAuth?.linked?.authToken else { throw Abort(.badRequest, reason: "User has no Plex account") }
            guard let clientIdentifier = req.parameters.get("clientIdentifier", as: String.self) else { throw Abort(.badRequest, reason: "Client identifier not provided") }
            guard let mediaID = req.parameters.get("mediaID", as: Int.self) else { throw Abort(.badRequest, reason: "Media ID not provided") }
            let type = (try? req.query.get(String.self, at: "protocol")) ?? "hls"
            let sessionID = try req.query.get(String.self, at: "sessionID")
            let plex = Plex()
            return plex.resources(client: req.client, token: token)
                .map { resources in
                    resources.first { $0.clientIdentifier == clientIdentifier }
                }
                .unwrap(orError: Abort(.badRequest, reason: "Resource not found"))
                .flatMapThrowing { resource in
                    resource.connections.map { connection in
                        var url = ""
                        if type == "hls" {
                            url = connection.uri.appendingPathComponent("/video/:/transcode/universal/start.m3u8").absoluteString
                            url += "?X-Plex-Token=\(resource.accessToken ?? "")"
                            url += "&X-Plex-Session-Identifier=\(sessionID)"
                            url += "&advancedSubtitles=text&audioBoost=100&autoAdjustQuality=0&directPlay=1&directStream=1&directStreamAudio=1&mediaBufferSize=20000&partIndex=0&path=%2Flibrary%2Fmetadata%2F\(mediaID)&protocol=hls&subtitleSize=150&subtitles=auto&videoQuality=100&videoResolution=4096x2160&X-Plex-Platform=Chrome&X-Plex-Client-Identifier=\(clientIdentifier)"
                        } else if type == "dash" {
                            url = connection.uri.appendingPathComponent("/video/:/transcode/universal/start.mpd").absoluteString
                            url += "?X-Plex-Token=\(resource.accessToken ?? "")"
                            url += "&X-Plex-Session-Identifier=\(sessionID)"
                            url += "&advancedSubtitles=text&audioBoost=100&autoAdjustQuality=0&directPlay=1&directStream=1&directStreamAudio=1&mediaBufferSize=20000&partIndex=0&path=%2Flibrary%2Fmetadata%2F\(mediaID)&protocol=dash&subtitleSize=150&subtitles=auto&videoQuality=100&videoResolution=4096x2160&X-Plex-Platform=Chrome&X-Plex-Client-Identifier=\(clientIdentifier)"
                        }
                        return url
                    }
                }
        }

        plex.get("resource", ":clientIdentifier", "timeline", ":mediaID") { req -> EventLoopFuture<[String]> in
            let user = try req.auth.require(User.self)
            guard let token = user.plexAuth?.linked?.authToken else { throw Abort(.badRequest, reason: "User has no Plex account") }
            guard let clientIdentifier = req.parameters.get("clientIdentifier", as: String.self) else { throw Abort(.badRequest, reason: "Client identifier not provided") }
            guard let mediaID = req.parameters.get("mediaID", as: Int.self) else { throw Abort(.badRequest, reason: "Media ID not provided") }
            let sessionID = try req.query.get(String.self, at: "sessionID")
            let plex = Plex()
            return plex.resources(client: req.client, token: token)
                .map { resources in
                    resources.first { $0.clientIdentifier == clientIdentifier }
                }
                .unwrap(orError: Abort(.badRequest, reason: "Resource not found"))
                .flatMapThrowing { resource in
                    resource.connections.map { connection in
                        var url = connection.uri.appendingPathComponent("/:/timeline").absoluteString
                            url += "?X-Plex-Token=\(resource.accessToken ?? "")"
                            url += "&X-Plex-Session-Identifier=\(sessionID)"
                            url += "&key=%2Flibrary%2Fmetadata%2F\(mediaID)&ratingKey=\(mediaID)&X-Plex-Platform=Chrome&X-Plex-Client-Identifier=\(clientIdentifier)"
                        return url
                    }
                }
        }

        plex.post("resource", ":clientIdentifier", "stream", ":mediaID", "capture") { req -> EventLoopFuture<File> in
            let user = try req.auth.require(User.self)
            guard let token = user.plexAuth?.linked?.authToken else { throw Abort(.badRequest, reason: "User has no Plex account") }
            guard let clientIdentifier = req.parameters.get("clientIdentifier", as: String.self) else { throw Abort(.badRequest, reason: "Client identifier not provided") }
            guard let mediaID = req.parameters.get("mediaID", as: Int.self) else { throw Abort(.badRequest, reason: "Media ID not provided") }
            
            let sessionID = try req.query.get(String.self, at: "sessionID")

            try PlexCaptureRequest.validate(content: req)
            let object = try req.content.decode(PlexCaptureRequest.self)

            let plex = Plex()
            return plex.resources(client: req.client, token: token)
                .map { resources in
                    resources.first { $0.clientIdentifier == clientIdentifier }
                }
                .unwrap(orError: Abort(.badRequest, reason: "Resource not found"))
                .throwingFlatMap { resource in
                    guard let connection = resource.connections.first(where: { !$0.local }) else {
                        throw Abort(.badRequest)
                    }
                    var url = connection.uri.appendingPathComponent("/video/:/transcode/universal/start.m3u8").absoluteString
                    url += "?X-Plex-Token=\(resource.accessToken ?? "")"
                    url += "&X-Plex-Session-Identifier=\(sessionID)"
                    url += "&advancedSubtitles=text&audioBoost=100&autoAdjustQuality=0&directPlay=1&directStream=1&directStreamAudio=1&mediaBufferSize=20000&partIndex=0&path=%2Flibrary%2Fmetadata%2F\(mediaID)&protocol=hls&subtitleSize=150&subtitles=auto&videoQuality=100&videoResolution=4096x2160&X-Plex-Platform=Chrome&offset=\(object.startTime)&X-Plex-Client-Identifier=\(clientIdentifier)"
                    let task = Process()
                    let directory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Temp")
                    task.currentDirectoryURL = directory
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    let uuid = UUID().uuidString
                    let fileURL = directory.appendingPathComponent(uuid).appendingPathExtension("m4a")

                    var env = task.environment ?? [:]
                    env["PATH"] = "/usr/bin:/usr/local/bin:/opt/homebrew/bin"
                    task.environment = env

                    task.arguments = [
                        "ffmpeg",
                        "-ss", Self.stringFromTimeInterval(interval: 0),
                        "-to", Self.stringFromTimeInterval(interval: object.endTime - object.startTime),
                        "-i", url,
                        "-c:a", "aac",
                        "-b:a", "128k",
                        "-map", "a",
                        "\(uuid).m4a"
                    ]
                    try task.run()
                    task.waitUntilExit()
                    if task.terminationStatus != 0 {
                        throw Abort(.internalServerError)
                    }

                    let data = try Data(contentsOf: fileURL)
                    try FileManager.default.removeItem(at: fileURL)
                    let file = File(owner: user, size: data.count, data: data)
                    return file.create(on: req.db).map {
                        file
                    }
                }
        }

        let reader = guardedMedia.grouped("reader")
        let sessions = reader.grouped("sessions")
        let session = reader.grouped("session")
        let sessionID = session.grouped(":id")

        sessions.get() { (req: Request) -> EventLoopFuture<Page<ReaderSession>> in
            let user = try req.auth.require(User.self)
            return user.$readerSessions
                .query(on: req.db)
                .field(\.$id).field(\.$textContent).field(\.$title).field(\.$url).field(\.$visualType).field(\.$rubyType).field(\.$owner.$id).field(\.$scrollPhraseIndex).field(\.$showReaderOptions)
                .sort(\.$updatedAt, .descending)
                .paginate(for: req).map {
                    let page = $0
                    for item in page.items {
                        item.$annotatedContent.value = ""
                        item.$content.value = ""
                    }
                    return page
                }
        }

        struct ReaderSessionSearchResult: Content {
            struct Session: Content {
                let id: UUID
                let title: String?
                let url: String?
            }
            let text: String
            let session: Session
        }

        sessions.get("search") { (req: Request) -> EventLoopFuture<Page<ReaderSessionSearchResult>> in
            let user = try req.auth.require(User.self)
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            let modifiedQuery = q.components(separatedBy: "|").filter { !$0.isEmpty }
            return user.$readerSessions
                .query(on: req.db)
                .group(.or) {
                    $0.filter(all: modifiedQuery) { text in
                        \.$textContent ~~ text
                    }
                }
                .field(\.$id).field(\.$textContent).field(\.$title).field(\.$url).field(\.$visualType).field(\.$rubyType).field(\.$owner.$id).field(\.$scrollPhraseIndex).field(\.$showReaderOptions)
                .sort(\.$updatedAt, .descending)
                .paginate(for: req).flatMapThrowing {
                    let page = $0
                    for item in page.items {
                        item.$annotatedContent.value = ""
                        item.$content.value = ""
                    }
                    return try page.flatMap { session in
                        let texts = session.textContent.splitSeparator(by: {
                            switch $0 {
                            case "\r\n", "\r", "\n", "\"", "「", "」": return .remove
                            case "。", ".", "？", "?": return .keepLeft
                            default: return .notSeparator
                            }
                        }).map { String($0) }.filter { o in !modifiedQuery.filter { q in o.contains(q) }.isEmpty }

                        return try texts.map {
                            ReaderSessionSearchResult(text: $0, session: ReaderSessionSearchResult.Session(id: try session.requireID(), title: session.title, url: session.url))
                        }
                    }
                }
        }

        session.post() { (req: Request) -> EventLoopFuture<ReaderSession> in
            let user = try req.auth.require(User.self)
            try ReaderSession.Create.validate(content: req)
            let object = try req.content.decode(ReaderSession.Create.self)
            let session = ReaderSession(owner: user, annotatedContent: object.annotatedContent, textContent: object.textContent, content: object.content, rubyType: object.rubyType, visualType: object.visualType, url: object.url, title: object.title)
            return session
                .create(on: req.db)
                .map {
                    session
                }
        }

        sessionID.get() { (req: Request) -> EventLoopFuture<ReaderSession.Response> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            let includeMediaSubtitles = (try? req.query.get(Bool.self, at: "includeMediaSubtitles")) ?? false
            var query = user.$readerSessions
                .query(on: req.db)
                .filter(\.$id == id)

            if includeMediaSubtitles {
                query = query.with(\.$media) {
                    $0.with(\.$subtitles)
                }
            } else {
                query = query.with(\.$media)
            }

            return query.first()
                .unwrap(or: Abort(.notFound))
                .flatMapThrowing {
                    let fileURL = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Files").appendingPathComponent("Sessions").appendingPathComponent("\(try $0.requireID()).sentences")
                    let sentencesData = try? Data(contentsOf: fileURL)
                    let sentences = sentencesData.flatMap { try? IkigaJSONDecoder().decode([SimpleSentence].self, from: $0) }
                    return ReaderSession.Response(
                        id: try $0.requireID(),
                        annotatedContent: $0.annotatedContent,
                        textContent: $0.textContent,
                        content: $0.content,
                        rubyType: $0.rubyType,
                        visualType: $0.visualType,
                        url: $0.url,
                        sentences: sentences,
                        scrollPhraseIndex: $0.scrollPhraseIndex,
                        showReaderOptions: $0.showReaderOptions,
                        title: $0.title,
                        media: $0.media,
                        updatedAt: $0.updatedAt
                    )
                }
        }

        sessionID.put() { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            try ReaderSession.Update.validate(content: req)
            let object = try req.content.decode(ReaderSession.Update.self)
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            return user.$readerSessions
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(or: Abort(.notFound))
                .throwingFlatMap { session in
                    if let annotatedContent = object.annotatedContent {
                        session.annotatedContent = annotatedContent
                    }
                    if let textContent = object.textContent {
                        session.textContent = textContent
                    }
                    if let content = object.content {
                        session.content = content
                    }
                    if let sentences = object.sentences {
                        let sessionsURL = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Files").appendingPathComponent("Sessions")
                        let fileURL = sessionsURL.appendingPathComponent("\(try session.requireID()).sentences")
                        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true, attributes: nil)
                        let data = try JSONEncoder().encode(sentences)
                        try data.write(to: fileURL)
                    }
                    session.$media.id = object.mediaID
                    session.rubyType = object.rubyType
                    session.visualType = object.visualType
                    session.scrollPhraseIndex = object.scrollPhraseIndex
                    session.showReaderOptions = object.showReaderOptions
                    return session.update(on: req.db)
                        .map { Response(status: .ok) }
                }
        }

        session.get("url", ":url") { (req: Request) -> EventLoopFuture<ReaderSession> in
            let user = try req.auth.require(User.self)
            guard let rawURL = req.parameters.get("url", as: String.self) else { throw Abort(.badRequest, reason: "URL not provided") }
            guard let url = URL(string: rawURL) else {
                throw Abort(.badRequest, reason: "URL is malformed")
            }
            return user.$readerSessions
                .query(on: req.db)
                .filter(\.$url ~~ (url.path.count > 0 ? url.path : (url.host ?? url.absoluteString)))
                .all()
                .map { (sessions: [ReaderSession]) in
                    sessions.first { session in
                        guard let rawSURL = session.url, let sURL = URL(string: rawSURL) else {
                            return false
                        }

                        return url.host == sURL.host && url.path == sURL.path
                    }
                }
                .unwrap(or: Abort(.notFound))
        }
    }

}
