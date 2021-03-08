import Fluent
import Vapor

class DictionaryController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let dictionary = routes.grouped("dictionary")
            .grouped(User.guardMiddleware())

        dictionary.get("exact") { (req: Request) -> EventLoopFuture<Page<Headword>> in
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            let modifiedQuery = q.applyingTransform(.hiraganaToKatakana, reverse: false) ?? q
            return Headword
                .query(on: req.db)
                .with(\.$dictionary)
                .join(parent: \.$dictionary)
                .group(.or) {
                    $0.filter(all: modifiedQuery.components(separatedBy: "|").filter { !$0.isEmpty }) { text in
                        \.$text == text
                    }
                }
                .sort(\.$text)
                .sort(Dictionary.self, \.$name)
                .paginate(for: req)
        }

        dictionary.get("search") { (req: Request) -> EventLoopFuture<Page<Headword>> in
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            var modifiedQuery = (q.applyingTransform(.hiraganaToKatakana, reverse: false) ?? q).replacingOccurrences(of: "?", with: "_").replacingOccurrences(of: "*", with: "%")
            if !modifiedQuery.contains("%") && !modifiedQuery.contains("_") {
                modifiedQuery = "\(modifiedQuery)%"
            }
            return Headword
                .query(on: req.db)
                .with(\.$dictionary)
                .join(parent: \.$dictionary)
                .filter(\.$text, .custom("LIKE"), modifiedQuery)
                .sort(\.$text)
                .sort(Dictionary.self, \.$name)
                .paginate(for: req)
        }

        dictionary.get("icon", ":dictionaryID") { (req: Request) -> EventLoopFuture<Response> in
            let id = try req.parameters.require("dictionaryID", as: UUID.self)
            return Dictionary
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMapThrowing { dictionary in
                    let data = DictionaryManager.shared.icons[dictionary.directoryName]!
                    let response = Response(status: .ok)
                    response.headers.contentType = HTTPMediaType.png
                    let filename = "\(id.uuidString).png"
                    response.headers.contentDisposition = .init(.attachment, filename: filename)
                    response.body = .init(data: data)
                    return response
                }
        }

        dictionary.get("entry", ":id") { (req: Request) -> EventLoopFuture<String> in
            let id = try req.parameters.require("id", as: UUID.self)
            return Headword
                .query(on: req.db)
                .with(\.$dictionary)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMapThrowing { headword in
                    let dictionary = headword.dictionary.directoryName
                    let container = DictionaryManager.shared.containers[dictionary]!
                    let css = DictionaryManager.shared.cssStrings[dictionary]!
                    let cssWordMappings = DictionaryManager.shared.cssWordMappings[dictionary]!
                    let contentIndex = DictionaryManager.shared.contentIndexes[dictionary]!

                    let realEntryIndex = contentIndex.indexMapping[headword.entryIndex]!
                    let file = container.files[realEntryIndex]
                    var text = file.text
                    for (original, replacement) in cssWordMappings {
                        text = text
                            .replacingOccurrences(of: "<\(original) ", with: "<\(replacement) ")
                            .replacingOccurrences(of: "<\(original)>", with: "<\(replacement)>")
                            .replacingOccurrences(of: "</\(original) ", with: "</\(replacement) ")
                            .replacingOccurrences(of: "</\(original)>", with: "</\(replacement)>")
                            .replacingOccurrences(of: "\"\(original)\"", with: "\"\(replacement)\"")
                            .replacingOccurrences(of: "<entry-index id=\"index\"/>", with: "")
                            .replacingOccurrences(of: "<entry-index xmlns=\"\" id=\"index\"/>", with: "")
                    }
                    text.replaceNonASCIIHTMLNodes()
                    return "<style>\(css)</style>\(text)"
                }
        }
    }

}
