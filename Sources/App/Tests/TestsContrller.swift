import Fluent
import MeCab
import Vapor
import Yams

class TestsController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let tests = routes.grouped("tests")
            .grouped(User.guardMiddleware())

        let pitchAccent = tests.grouped("pitchAccent")
        let names = pitchAccent.grouped("names")
        let counters = pitchAccent.grouped("counters")
        let minimalPairs = pitchAccent.grouped("minimalPairs")

        counters.get("all") { req -> [Counter] in
            return PitchAccentManager.shared.allCounters
        }

        struct RandomCounterNumber: Content {
            let number: String
            let counter: String
            let kana: String
            let usage: String?
            let accents: [PitchAccentEntry.AccentGroup]
        }

        counters.post("random") { (req: Request) -> RandomCounterNumber in
            let counterIDs = try req.content.decode([String].self)
            guard let counterID = counterIDs.randomElement() else {
                throw Abort(.badRequest)
            }
            guard let counter = PitchAccentManager.shared.counters.first(where: { $0.id == counterID }) else {
                throw Abort(.notFound)
            }
            guard let entry = counter.subentries.filter({ !$0.accents.isEmpty }).randomElement() else {
                throw Abort(.internalServerError)
            }
            return RandomCounterNumber(number: entry.number ?? "", counter: counter.kanji.count > 0 ? counter.kanji[0] : counter.kana, kana: counter.kana, usage: counter.usage, accents: entry.accents)
        }

        names.get("random") { (req: Request) -> RandomName in
            var name = randomName()
            while !name.isMecabable() {
                name = randomName()
            }
            return name
        }

        names.get("speech", ":gender", ":firstNameIndex", ":lastNameIndex") { (req: Request) -> EventLoopFuture<Response> in
            guard let genderString = req.parameters.get("gender", as: String.self), let gender = RandomName.Gender(rawValue: genderString) else { throw Abort(.badRequest, reason: "Gender not provided") }
            let allFirstNames = PitchAccentManager.shared.randomNames.firstNames
            let firstNames = gender == .female ? allFirstNames.female : allFirstNames.male
            let lastNames = PitchAccentManager.shared.randomNames.lastNames
            guard let firstNameIndex = req.parameters.get("firstNameIndex", as: Int.self), let lastNameIndex = req.parameters.get("lastNameIndex", as: Int.self), firstNameIndex < firstNames.count && lastNameIndex < lastNames.count else {
                throw Abort(.badRequest, reason: "Invalid name indices provided")
            }
            let firstName = firstNames[firstNameIndex]
            let lastName = lastNames[lastNameIndex]

            let mecab = try Mecab()
            let nodes = try mecab.tokenize(string: "\(lastName.kanji)\(firstName.kanji)").filter { $0.type == .normal && $0.partOfSpeechSubType == "固有名詞" && $0.features[2] == "人名" }
            let lastNameNode = nodes[0]
            let firstNameNode = nodes[1]
            let ssmlString = """
            <speak>
                <prosody rate="95%">
                    <phoneme alphabet="x-amazon-pron-kana" ph="\(lastNameNode.sapiPronunciation)">
                        \(lastNameNode.surface)
                    </phoneme>
                    <phoneme alphabet="x-amazon-pron-kana" ph="\(firstNameNode.sapiPronunciation)">
                        \(firstNameNode.surface)
                    </phoneme>
                </prosody>
            </speak>
            """

            let synthesis = SpeechSynthesis(engine: "standard", languageCode: "ja-JP", lexiconNames: [], outputFormat: "mp3", sampleRate: "22050", speechMarkTypes: [], text: ssmlString, textType: "ssml", voiceId: "Mizuki")
            let encoder = JSONEncoder()
            let synthesisData = try encoder.encode(synthesis)

            let url = URI(string: "https://polly.us-east-2.amazonaws.com/v1/speech")
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")
            return req.client.post(url, headers: headers, beforeSend: {
                let signer = AWSSigner(awsRegion: "us-east-2", serviceType: "polly")
                $0.body = .init(data: synthesisData)
                signer.sign(request: &$0, secretSigningKey: Config.shared.awsSecretKey, accessKeyId: Config.shared.awsAccessKeyId)
            }).flatMapThrowing {
                guard let buffer = $0.body else {
                    throw Abort(.internalServerError)
                }
                let allData = Data(buffer: buffer)
                let rangeString = req.headers.first(name: .range) ?? ""
                let response = Response(status: .ok)
                response.headers.contentType = HTTPMediaType.audio
                let filename = "name.m4a"
                response.headers.contentDisposition = .init(.attachment, filename: filename)
                if rangeString.count > 0 {
                    let range = try Range.parse(tokenizer: .init(input: rangeString))
                    let data = allData[range.startByte...min(range.endByte, allData.endIndex - 1)]
                    response.headers.add(name: .contentRange, value: "bytes \(data.startIndex)-\(data.endIndex)/\(allData.count)")
                    response.headers.add(name: .contentLength, value: String(data.count))
                    response.body = .init(data: data)
                } else {
                    response.body = .init(data: allData)
                }
                return response
            }
        }

        minimalPairs.get("random") { (req: Request) -> MinimalPair in
            return PitchAccentManager.shared.minimalPairs.randomElement()!
        }
    }

}
