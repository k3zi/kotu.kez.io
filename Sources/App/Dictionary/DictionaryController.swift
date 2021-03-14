import Fluent
import MeCab
import Vapor

class DictionaryController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let dictionary = routes.grouped("dictionary")
            .grouped(User.guardMiddleware())
        let dictionaryID = dictionary.grouped(":id")

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

        dictionaryID.delete() { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            let id = try req.parameters.require("id", as: UUID.self)
            return user.$dictionaries
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(or: Abort(.notFound))
                .flatMap { (dictionary: Dictionary) in
                    dictionary.$owners.detach(user, on: req.db)
                        .flatMap {
                            dictionary.$owners.query(on: req.db).count()
                        }
                        .flatMap { ownersCount in
                            if ownersCount != .zero {
                                return req.eventLoop.future(Response(status: .ok))
                            }

                            let job = DictionaryRemoveJob(dictionary: dictionary)
                            return job.create(on: req.db)
                                .map { Response(status: .ok) }
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
                .map { page in
                    Page(items: Swift.Dictionary(grouping: page.items, by: { $0.$entry.id }).flatMap { (key: UUID?, value: [Headword]) -> [Headword] in key == nil ? value : [value.first!] }, metadata: page.metadata)
                }
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
                .map { page in
                    Page(items: Swift.Dictionary(grouping: page.items, by: { $0.$entry.id }).flatMap { (key: UUID?, value: [Headword]) -> [Headword] in key == nil ? value : [value.first!] }, metadata: page.metadata)
                }
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
            let forceHorizontalText = (try? req.query.get(Bool.self, at: "forceHorizontalText")) ?? false
            let forceDarkCSS = (try? req.query.get(Bool.self, at: "forceDarkCSS")) ?? false
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
                    var css = (forceDarkCSS && headword.dictionary.darkCSS.count > 0) ? headword.dictionary.darkCSS : headword.dictionary.css
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
                    let horizontalTextCSS = """
                    body {
                        writing-mode: horizontal-tb !important;
                    }
                    """
                    return """
                    <style>
                        \(css)
                        \(forceHorizontalText ? horizontalTextCSS : "")
                    </style>
                    <script>
                        document.addEventListener('copy', function (e) {
                            e.preventDefault();
                            const rts = [...document.getElementsByTagName('rt')];
                            rts.forEach(rt => {
                                rt.style.display = 'none';
                            });
                            e.clipboardData.setData('text', window.getSelection().toString());
                            rts.forEach(rt => {
                                rt.style.removeProperty('display');
                            });
                        });
                    </script>
                    \(text)
                    """
                }
        }

        dictionary.post("parse") { (req: Request) -> EventLoopFuture<[Sentence]> in
            struct Offset {
                let accentPhraseComponent: AccentPhraseComponent
                let accentPhraseComponentOffset: Int
                let accentPhraseOffset: Int
                let sentenceOffset: Int
            }
            let user = try req.auth.require(User.self)
            guard let sentenceString = req.body.string, sentenceString.count > 0 else { throw Abort(.badRequest, reason: "Empty sentence passed.") }
            let includeHeadwords = (try? req.query.get(Bool.self, at: "includeHeadwords")) ?? false
            let includeListWords = (try? req.query.get(Bool.self, at: "includeListWords")) ?? false
            let mecab = try Mecab()
            let nodes = try mecab.tokenize(string: sentenceString)
            let listWordsFuture = includeListWords
                ? user.$listWords.query(on: req.db).all()
                : req.eventLoop.future([])
            var sentences = try Sentence.parseMultiple(db: req.db, tokenizer: .init(nodes: nodes))

            // Headwords are required for the list words so it doesn't make sense
            // going past this point.
            if !includeHeadwords {
                return req.eventLoop.future(sentences)
            }
            return listWordsFuture
                .flatMap { listWords -> EventLoopFuture<[Sentence]> in
                    let offsets = sentences.enumerated().flatMap { (sentenceOffset, sentence) in
                        sentence.accentPhrases.enumerated().flatMap { (accentPhraseOffset, accentPhrase) in
                            accentPhrase.components.enumerated().map { (componentOffset, component) in
                                Offset(accentPhraseComponent: component, accentPhraseComponentOffset: componentOffset, accentPhraseOffset: accentPhraseOffset, sentenceOffset: sentenceOffset)
                            }
                        }
                    }

                    let offsetFutures: [EventLoopFuture<(Offset, [Headword])>] = offsets.map { offset in
                        let component = offset.accentPhraseComponent
                        if component.isBasic || !includeHeadwords {
                            return req.eventLoop.future((offset, []))
                        }
                        return Headword.query(on: req.db)
                            .group(.or) {
                                $0.filter(all: [component.original.katakana, component.surface.katakana]) { text in
                                    \.$text == text
                                }
                            }
                            .sort(\.$text)
                            .limit(3)
                            .all()
                            .map {
                                return (offset, $0)
                            }
                    }

                    return EventLoopFuture.whenAllSucceed(offsetFutures, on: req.eventLoop)
                        .map {
                            for (offset, headwords) in $0 {
                                sentences[offset.sentenceOffset].accentPhrases[offset.accentPhraseOffset].components[offset.accentPhraseComponentOffset].headwords = headwords
                                if includeHeadwords && includeListWords {
                                    sentences[offset.sentenceOffset].accentPhrases[offset.accentPhraseOffset].components[offset.accentPhraseComponentOffset].listWords = listWords.filter { listWord in headwords.contains { $0.headline == listWord.value } }
                                }
                            }
                            return sentences
                        }
                }
        }
    }

}

extension QueryBuilder {

    @discardableResult
    public func filter<A>(all: [A], _ filter: (A) -> FluentKit.ModelValueFilter<Model>) -> Self {
        if all.isEmpty {
            return self
        }

        var modAll = all
        let next = modAll.removeFirst()
        return self.filter(filter(next)).filter(all: modAll, filter)
    }

}
