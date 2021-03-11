import Fluent
import Vapor

class DictionaryController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let dictionary = routes.grouped("dictionary")
            .grouped(User.guardMiddleware())

        dictionary.get("all") { (req: Request) -> EventLoopFuture<[Dictionary]> in
            let user = try req.auth.require(User.self)
            return user.$dictionaries
                .query(on: req.db)
                .with(\.$insertJob)
                .all()
        }

        dictionary.post("upload") { (req: Request) -> EventLoopFuture<Dictionary> in
            struct Upload: Content {
                let dictionaryFile: Vapor.File
            }
            let user = try req.auth.require(User.self)
            let file = try req.content.decode(Upload.self).dictionaryFile
            let data = Data(buffer: file.data)
            let hashed = SHA256.hash(data: data)
            let sha = hashed.compactMap { String(format: "%02x", $0) }.joined()
            return Dictionary.query(on: req.db)
                .filter(\.$sha == sha)
                .first()
                .throwingFlatMap { (existingDictionary: Dictionary?) in
                    if let dictionary = existingDictionary {
                        return user.$dictionaries.attach(dictionary, on: req.db).map { dictionary }
                    } else {
                        let dictionary = Dictionary(name: file.filename, sha: sha)
                        let uuid = UUID().uuidString
                        let directory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Temp").appendingPathComponent(uuid)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        try data.write(to: directory.appendingPathComponent(file.filename))
                        return dictionary.create(on: req.db)
                            .flatMap { user.$dictionaries.attach(dictionary, on: req.db)
                            }
                            .flatMap {
                                DictionaryInsertJob(dictionary: dictionary, tempDirectory: uuid, filename: file.filename, type: "unknown", currentEntryIndex: 0, currentHeadwordIndex: 0)
                                    .create(on: req.db)
                            }
                            .throwingFlatMap { Dictionary.query(on: req.db).with(\.$insertJob).filter(\.$id == (try dictionary.requireID())).first().unwrap(or: Abort(.internalServerError)) }
                    }
                }
        }

        dictionary.get("exact") { (req: Request) -> EventLoopFuture<Page<Headword>> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            let modifiedQuery = q.applyingTransform(.hiraganaToKatakana, reverse: false) ?? q
            return Headword
                .query(on: req.db)
                .with(\.$dictionary)
                .join(parent: \.$dictionary)
                .join(from: Dictionary.self, siblings: \.$owners)
                .filter(User.self, \.$id == userID)
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
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
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
                .join(from: Dictionary.self, siblings: \.$owners)
                .filter(\.$text, .custom("LIKE"), modifiedQuery)
                .filter(User.self, \.$id == userID)
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
                    guard let data = dictionary.icon ?? DictionaryManager.shared.icons[dictionary.directoryName] else {
                        throw Abort(.notFound)
                    }
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
                .with(\.$entry)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMapThrowing { headword in
                    let dictionary = headword.dictionary.directoryName
                    var text = ""
                    var css = headword.dictionary.css
                    var cssWordMappings = [String: String]()
                    if !dictionary.isEmpty {
                        css = DictionaryManager.shared.cssStrings[dictionary]!
                        cssWordMappings = DictionaryManager.shared.cssWordMappings[dictionary]!

                        let container = DictionaryManager.shared.containers[dictionary]!
                        let contentIndex = DictionaryManager.shared.contentIndexes[dictionary]!

                        let realEntryIndex = contentIndex.indexMapping[headword.entryIndex]!
                        let file = container.files[realEntryIndex]
                        text = file.text
                    } else {
                        cssWordMappings = css.replaceNonASCIICharacters()
                        text = headword.entry?.content ?? ""
                    }
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
