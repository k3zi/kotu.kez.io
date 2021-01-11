import Fluent
import MeCab
import Vapor

extension Node {

    var original: String {
        (features.count > 7 ? features[7] : "").split(separator: "-").first.flatMap { String($0) } ?? ""
    }

    var partOfSpeech: String {
        features[0]
    }

    var partOfSpeechSubType: String {
        features[1]
    }

    var isGenerallyIgnored: Bool {
        ["連体詞", "助詞", "補助記号", "助動詞", "補助記号", "空白"].contains(partOfSpeech)
            ||
        ["数詞"].contains(partOfSpeechSubType)
    }

    func shouldIgnore(for user: User) -> Bool {
        isBasic || user.ignoreWords.contains(original)
    }

    var isBasic: Bool {
        isBosEos || isGenerallyIgnored
    }

    var shouldDisplay: Bool {
        !isBosEos
    }

}

struct ParseResult: Content {

    let surface: String
    let original: String
    let shouldDisplay: Bool
    let isBasic: Bool
    let frequency: Frequency
    let headwords: [Headword]
    let listWords: [ListWord]

}

class ListsController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let dictionary = routes.grouped("lists")
            .grouped(User.guardMiddleware())

        let word = dictionary.grouped("word")
        let words = dictionary.grouped("words")
        let sentence = dictionary.grouped("sentence")

        word.get("first") { (req: Request) -> EventLoopFuture<ListWord> in
            let user = try req.auth.require(User.self)
            let isLookup = (try? req.query.get(Bool.self, at: "isLookup")) ?? false
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            return user
                .$listWords
                .query(on: req.db)
                .filter(\.$value =~ q)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMap { word in
                    if isLookup {
                        word.lookups += 1
                        return word.save(on: req.db)
                            .map { word }
                    } else {
                        return req.eventLoop.future(word)
                    }
                }
        }

        word.post() { (req: Request) -> EventLoopFuture<ListWord> in
            let user = try req.auth.require(User.self)

            try ListWord.Create.validate(content: req)
            let object = try req.content.decode(ListWord.Create.self)
            let listWord = ListWord(owner: user, value: object.value, note: object.note ?? "", tags: object.tags ?? [])

            return listWord
                .save(on: req.db)
                .map { listWord }
        }

        word.delete(":wordID") { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            guard let wordID = req.parameters.get("wordID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user
                .$listWords
                .query(on: req.db)
                .filter(\.$id == wordID)
                .delete()
                .map {
                    Response(status: .ok)
                }
        }

        word.put(":wordID") { (req: Request) -> EventLoopFuture<ListWord> in
            let user = try req.auth.require(User.self)
            guard let wordID = req.parameters.get("wordID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try ListWord.Put.validate(content: req)
            let object = try req.content.decode(ListWord.Put.self)

            return user
                .$listWords
                .query(on: req.db)
                .filter(\.$id == wordID)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMap { word in
                    word.value = object.value
                    word.note = object.note
                    word.tags = object.tags
                    return word.save(on: req.db)
                        .map {
                            word
                        }
                }
        }

        words.get() { (req: Request) -> EventLoopFuture<[ListWord]> in
            let user = try req.auth.require(User.self)
            return user
                .$listWords
                .query(on: req.db)
                .sort(\.$createdAt, .descending)
                .all()
        }

        sentence.put("ignore") { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            let word = try req.content.get(String.self, at: "word").trimmingCharacters(in: .whitespacesAndNewlines)
            guard word.count > 0 else { throw Abort(.badRequest, reason: "Empty word passed.") }

            if !user.ignoreWords.contains(word) {
                user.ignoreWords.append(word)
            }
            return user.save(on: req.db)
                .map { Response(status: .ok) }
        }

        sentence.post("parse") { (req: Request) -> EventLoopFuture<[ParseResult]> in
            let user = try req.auth.require(User.self)
            let sentence = try req.content.get(String.self, at: "sentence").trimmingCharacters(in: .whitespacesAndNewlines)
            guard sentence.count > 0 else { throw Abort(.badRequest, reason: "Empty sentence passed.") }
            let mecab = try Mecab()
            let nodes = try mecab.tokenize(string: sentence)
            let resultsFutures: [EventLoopFuture<(Node, [Headword])>] = nodes.map { node in
                if node.shouldIgnore(for: user) {
                    return req.eventLoop.future((node, []))
                }
                return Headword.query(on: req.db)
                    .filter(\.$text == node.original.applyingTransform(.hiraganaToKatakana, reverse: false) ?? node.original)
                    .sort(\.$text)
                    .limit(5)
                    .all()
                    .map {
                        (node, $0)
                    }
            }
            let resultsFuture = EventLoopFuture.whenAllSucceed(resultsFutures, on: req.eventLoop)

            return user.$listWords.query(on: req.db)
                .all()
                .and(resultsFuture)
                .map { (listWords, results) in
                    results.map { (node, headwords) in
                        let frequencyItem = DictionaryManager.shared.frequencyList[node.original] ?? DictionaryManager.shared.frequencyList[node.surface]
                        return ParseResult(surface: node.surface, original: node.original, shouldDisplay: node.shouldDisplay, isBasic: node.isBasic, frequency: frequencyItem?.frequency ?? .unknown, headwords: Array(headwords.prefix(3)), listWords: listWords.filter { listWord in headwords.contains { $0.headline == listWord.value } })
                    }
                }
        }
    }

}
