import Fluent
import Vapor

class ListsController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let dictionary = routes.grouped("lists")
            .grouped(User.guardMiddleware())

        let word = dictionary.grouped("word")
        let words = dictionary.grouped("words")

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
    }

}
