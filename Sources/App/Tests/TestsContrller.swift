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
        let minimalPairs = pitchAccent.grouped("minimalPairs")

        struct RandomName: Content {
            enum Gender: String, CaseIterable, Content {
                case male
                case female
            }

            let gender: Gender
            let firstName: RandomNames.Name
            let firstNameIndex: Int
            var firstNamePitchAccent: PitchAccent
            var firstNamePronunciation: String
            let lastName: RandomNames.Name
            let lastNameIndex: Int
            var lastNamePitchAccent: PitchAccent
            var lastNamePronunciation: String

            mutating func isMecabable() -> Bool {
                let mecab = try! Mecab()
                let nodes = try! mecab.tokenize(string: "\(lastName.kanji)\(firstName.kanji)").filter { $0.type == .normal }
                guard nodes.count == 2 && nodes[0].features[3] == "姓" && nodes[1].features[3] == "名" && nodes.allSatisfy({ $0.partOfSpeechSubType == "固有名詞" && $0.features[2] == "人名" && $0.pitchAccents.count == 1 }) else { return false }
                lastNamePitchAccent = nodes[0].pitchAccents[0]
                lastNamePronunciation = nodes[0].pronunciation
                firstNamePitchAccent = nodes[1].pitchAccents[0]
                firstNamePronunciation = nodes[1].pronunciation
                let pronunciation = nodes.map { $0.rawPronunciation }.joined()
                return pronunciation.katakana == "\(lastName.katakana)\(firstName.katakana)"
            }
        }

        func randomName() -> RandomName {
            let gender = RandomName.Gender.allCases.randomElement()!
            let firstNames = PitchAccentManager.shared.randomNames.firstNames
            let firstName = Array((gender == .female ? firstNames.female : firstNames.male).enumerated()).randomElement()!
            let lastName = Array(PitchAccentManager.shared.randomNames.lastNames.enumerated()).randomElement()!
            return .init(gender: gender, firstName: firstName.element, firstNameIndex: firstName.offset, firstNamePitchAccent: .init(mora: 0, length: 0), firstNamePronunciation: "", lastName: lastName.element, lastNameIndex: lastName.offset, lastNamePitchAccent: .init(mora: 0, length: 0), lastNamePronunciation: "")
        }

        names.get("random") { (req: Request) -> RandomName in
            var name = randomName()
            while !name.isMecabable() {
                name = randomName()
            }
            return name
        }

        struct AWSSigner {
            let awsRegion: String
            let serviceType: String
            private let hmacShaTypeString = "AWS4-HMAC-SHA256"
            private let aws4Request = "aws4_request"

            private let iso8601Formatter: DateFormatter = {
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .iso8601)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "yyyyMMdd'T'HHmmssXXXXX"
                return formatter
            }()

            private func iso8601() -> (full: String, short: String) {
                let date = iso8601Formatter.string(from: Date())
                let index = date.index(date.startIndex, offsetBy: 8)
                let shortDate = date.substring(to: index)
                return (full: date, short: shortDate)
            }

            func sign(request: inout ClientRequest, secretSigningKey: String, accessKeyId: String) {
                let date = iso8601()
                let url = request.url

                guard let bodyBuffer = request.body, let host = url.host else { return }
                let body = Data(buffer: bodyBuffer)

                request.headers.add(name: .host, value: host)
                request.headers.add(name: "X-Amz-Date", value: date.full)
                let method = request.method

                let signedHeaders = request.headers.map { $0.name.lowercased() }.sorted().joined(separator: ";")

                let canonicalRequestHash = [
                    method.rawValue,
                    url.path,
                    url.query ?? "",
                    request.headers.map { $0.name.lowercased() + ":" + $0.value }.sorted().joined(separator: "\n"),
                    "",
                    signedHeaders,
                    body.sha256()
                ].joined(separator: "\n").sha256()

                let credential = [date.short, awsRegion, serviceType, aws4Request].joined(separator: "/")

                let stringToSign = [
                    hmacShaTypeString,
                    date.full,
                    credential,
                    canonicalRequestHash
                ].joined(separator: "\n")

                let signature = hmacStringToSign(stringToSign: stringToSign, secretSigningKey: secretSigningKey, shortDateString: date.short)

                let authorization = hmacShaTypeString + " Credential=" + accessKeyId + "/" + credential + ", SignedHeaders=" + signedHeaders + ", Signature=" + signature
                request.headers.add(name: .authorization, value: authorization)
            }

            private func hmacStringToSign(stringToSign: String, secretSigningKey: String, shortDateString: String) -> String {
                let k1 = "AWS4" + secretSigningKey
                let sk1 = HMAC<SHA256>.authenticationCode(for: [UInt8](shortDateString.utf8), using: .init(data: [UInt8](k1.utf8)))
                let sk2 = HMAC<SHA256>.authenticationCode(for: [UInt8](awsRegion.utf8), using: .init(data: sk1))
                let sk3 = HMAC<SHA256>.authenticationCode(for: [UInt8](serviceType.utf8), using: .init(data: sk2))
                let sk4 = HMAC<SHA256>.authenticationCode(for: [UInt8](aws4Request.utf8), using: .init(data: sk3))
                let signature = HMAC<SHA256>.authenticationCode(for: [UInt8](stringToSign.utf8), using: .init(data: sk4))
                return signature.hex
            }
        }

        struct SpeechSynthesis: Encodable {
            enum CodingKeys: String, CodingKey {
                case engine = "Engine"
                case languageCode = "LanguageCode"
                case lexiconNames = "LexiconNames"
                case outputFormat = "OutputFormat"
                case sampleRate = "SampleRate"
                case speechMarkTypes = "SpeechMarkTypes"
                case text = "Text"
                case textType = "TextType"
                case voiceId = "VoiceId"
            }
            let engine: String
            let languageCode: String
            let lexiconNames: [String]
            let outputFormat: String
            let sampleRate: String
            let speechMarkTypes: [String]
            let text: String
            let textType: String
            let voiceId: String
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
                response.headers.remove(name: .contentLength)
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
