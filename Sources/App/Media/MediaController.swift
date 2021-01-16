import Fluent
import Vapor

struct MediaCaptureRequest: Content {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let youtubeID: String
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
            .grouped(User.guardMiddleware())

        media.get("audio", ":id") { req -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user.$files
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMapThrowing { file in
                    let rangeString = req.headers.first(name: .range) ?? ""
                    let response = Response(status: .ok)
                    response.headers.contentType = HTTPMediaType.audio
                    let filename = "\(file.id!.uuidString).m4a"
                    response.headers.contentDisposition = .init(.attachment, filename: filename)
                    if rangeString.count > 0 {
                        let range = try Range.parse(tokenizer: .init(input: rangeString))
                        let data = file.data[range.startByte...min(range.endByte, file.data.endIndex - 1)]
                        response.headers.add(name: .contentRange, value: "bytes \(data.startIndex)-\(data.endIndex)/\(file.data.count)")
                        response.headers.add(name: .contentLength, value: String(data.count))
                        response.body = .init(data: data)
                    } else {
                        response.body = .init(data: file.data)
                    }
                    return response
                }
        }

        let youtube = media.grouped("youtube")

        youtube.post("capture") { req -> EventLoopFuture<File> in
            let user = try req.auth.require(User.self)

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
            task.launch()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                throw Abort(.internalServerError)
            }

            let fileURL = directory.appendingPathComponent(uuid).appendingPathExtension("m4a")
            let data = try Data(contentsOf: fileURL)
            try FileManager.default.removeItem(at: fileURL)

            let file = File(owner: user, size: data.count, data: data)
            return file.create(on: req.db).map {
                file
            }
        }

        let plex = media.grouped("plex")

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

        plex.get("resource", ":clientIdentifier", "stream", ":mediaID") { req -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            guard let token = user.plexAuth?.linked?.authToken else { throw Abort(.badRequest, reason: "User has no Plex account") }
            guard let clientIdentifier = req.parameters.get("clientIdentifier", as: String.self) else { throw Abort(.badRequest, reason: "Client identifier not provided") }
            guard let mediaID = req.parameters.get("mediaID", as: Int.self) else { throw Abort(.badRequest, reason: "Media ID not provided") }
            let plex = Plex()
            return plex.resources(client: req.client, token: token)
                .map { resources in
                    resources.first { $0.clientIdentifier == clientIdentifier }
                }
                .unwrap(orError: Abort(.badRequest, reason: "Resource not found"))
                .flatMapThrowing { resource in
                    guard let connection = resource.connections.first(where: { !$0.local }) else {
                        throw Abort(.badRequest)
                    }
                    var url = connection.uri.appendingPathComponent("/video/:/transcode/universal/start.m3u8").absoluteString
                    url += "?X-Plex-Token=\(resource.accessToken ?? "")"
                    url += "&advancedSubtitles=text&audioBoost=100&autoAdjustQuality=0&directPlay=1&directStream=1&directStreamAudio=1&mediaBufferSize=20000&partIndex=0&path=%2Flibrary%2Fmetadata%2F\(mediaID)&protocol=hls&subtitleSize=150&subtitles=auto&videoQuality=100&videoResolution=4096x2160&X-Plex-Platform=Chrome"
                    return req.redirect(to: url)
                }
        }

        plex.post("resource", ":clientIdentifier", "stream", ":mediaID", "capture") { req -> EventLoopFuture<File> in
            let user = try req.auth.require(User.self)
            guard let token = user.plexAuth?.linked?.authToken else { throw Abort(.badRequest, reason: "User has no Plex account") }
            guard let clientIdentifier = req.parameters.get("clientIdentifier", as: String.self) else { throw Abort(.badRequest, reason: "Client identifier not provided") }
            guard let mediaID = req.parameters.get("mediaID", as: Int.self) else { throw Abort(.badRequest, reason: "Media ID not provided") }

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
                    url += "&advancedSubtitles=text&audioBoost=100&autoAdjustQuality=0&directPlay=1&directStream=1&directStreamAudio=1&mediaBufferSize=20000&partIndex=0&path=%2Flibrary%2Fmetadata%2F\(mediaID)&protocol=hls&subtitleSize=150&subtitles=auto&videoQuality=100&videoResolution=4096x2160&X-Plex-Platform=Chrome&offset=\(object.startTime)"
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
                    task.launch()
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
    }

}
