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
                    let response = Response(status: rangeString.count > 0 ? .partialContent : .ok)
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
    }

}
