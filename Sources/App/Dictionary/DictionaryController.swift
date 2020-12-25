import Fluent
import Vapor

class DictionaryController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let dictionary = routes.grouped("dictionary")
            .grouped(User.guardMiddleware())

        dictionary.get("search") { (req: Request) -> EventLoopFuture<[Headword]> in
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            let modifiedQuery = q.applyingTransform(.hiraganaToKatakana, reverse: false) ?? q
            return Headword
                .query(on: req.db)
                .filter(\.$text =~ modifiedQuery)
                .limit(25)
                .all()
        }

        dictionary.get("entry", ":id") { (req: Request) -> EventLoopFuture<String> in
            let id = try req.parameters.require("id", as: UUID.self)
            return Headword.find(id, on: req.db)
                .unwrap(orError: Abort(.notFound))
                .flatMapThrowing { headword in
                    let dictionary = "SMK8"
                    let container = DictionaryManager.shared.containers[dictionary]!
                    let css = DictionaryManager.shared.cssStrings[dictionary]!
                    let cssWordMappings = DictionaryManager.shared.cssWordMappings[dictionary]!

                    let file = container.files[headword.entryIndex]
                    var text = file.text
                    for (original, replacement) in cssWordMappings {
                        text = text
                            .replacingOccurrences(of: "<\(original) ", with: "<\(replacement) ")
                            .replacingOccurrences(of: "<\(original)>", with: "<\(replacement)>")
                            .replacingOccurrences(of: "</\(original) ", with: "</\(replacement) ")
                            .replacingOccurrences(of: "</\(original)>", with: "</\(replacement)>")
                            .replacingOccurrences(of: "\"\(original)\"", with: "\"\(replacement)\"")
                            .replacingOccurrences(of: "<entry-index id=\"index\"/>", with: "")
                    }
                    text.replaceNonASCIIHTMLNodes()
                    return "<style>\(css)</style>\(text)"
                }
        }
    }

}
