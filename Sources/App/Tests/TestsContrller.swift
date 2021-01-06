import Fluent
import Vapor

class TestsController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let tests = routes.grouped("tests")
            .grouped(User.guardMiddleware())

        let pitchAccent = tests.grouped("pitchAccent")
        let minimalPairs = pitchAccent.grouped("minimalPairs")

        minimalPairs.get("random") { (req: Request) -> MinimalPair in
            return PitchAccentManager.shared.minimalPairs.randomElement()!
        }

        minimalPairs.get("audio", ":file") { req -> Response in
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
                response.headers.add(name: .contentRange, value: "bytes \(croppedData.startIndex)-\(croppedData.endIndex)/\(data.count)")
                response.headers.add(name: .contentLength, value: String(croppedData.count))
                response.body = .init(data: croppedData)
            } else {
                response.body = .init(data: data)
            }
            return response
        }
    }

}
