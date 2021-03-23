import Fluent
import MeCab
import Vapor

extension Data {

    func sha256() -> String {
        let hashed = SHA256.hash(data: self)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

}

extension String {

    func sha256() -> String {
        self.data(using: .utf8)!.sha256()
    }

}

class DictionaryController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let dictionary = routes.grouped("dictionary")
            .grouped(User.guardMiddleware())
        let dictionaryID = dictionary.grouped(":id")

        dictionary.get("all") { (req: Request) -> EventLoopFuture<[Dictionary.Simple]> in
            let user = try req.auth.require(User.self)
            return user.$dictionaries
                .query(on: req.db)
                .field(\.$name).field(\.$id)
                .with(\.$owners.$pivots)
                .with(\.$insertJob)
                .sort(DictionaryOwner.self, \.$order)
                .all()
                .map {
                    $0.map { Dictionary.Simple(dictionary: $0, user: user) }
                }
        }

        dictionary.put("all") { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            let objects = try req.content.decode([Dictionary.Update].self)
            return user.$dictionaries
                .query(on: req.db)
                .field(\.$id)
                .with(\.$owners.$pivots)
                .all()
                .flatMap { dictionaries in
                    let pivots = dictionaries.compactMap { dictionary -> DictionaryOwner? in
                        guard let object = objects.first(where: { $0.id == dictionary.id }) else {
                            return nil
                        }

                        let pivot = dictionary.$owners.pivots.filter { $0.$owner.id == user.id }.first
                        pivot?.order = object.order
                        return pivot
                    }

                    let futures = pivots.map { $0.save(on: req.db) }
                    return EventLoopFuture.whenAllComplete(futures, on: req.eventLoop)
                        .map { _ in Response(status: .ok) }
                }
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

        dictionary.get("exact") { (req: Request) -> EventLoopFuture<Page<Headword.Simple>> in
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
                .field(\.$headline).field(\.$shortHeadline).field(\.$dictionary.$id).field(\.$entry.$id).field(\.$entryIndex).field(\.$subentryIndex)
                .field(DictionaryOwner.self, \.$order)
                .sort(DictionaryOwner.self, \.$order)
                .sort(\.$headline)
                .unique()
                .paginate(for: req)
                .map { page in
                    let items = page.items.map { Headword.Simple(headword: $0) }
                    return Page(items: items, metadata: page.metadata)
                }
        }

        dictionary.get("search") { (req: Request) -> EventLoopFuture<Page<Headword.Simple>> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            let q = try req.query.get(String.self, at: "q").trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count > 0 else { throw Abort(.badRequest, reason: "Empty query passed.") }
            let katakanaQuery = q.applyingTransform(.hiraganaToKatakana, reverse: false) ?? q
            var modifiedQuery = katakanaQuery.replacingOccurrences(of: "?", with: "_").replacingOccurrences(of: "*", with: "%")
            if !modifiedQuery.contains("%") && !modifiedQuery.contains("_") {
                modifiedQuery = "\(modifiedQuery)%"
            }
            let exact = (try? req.query.get(Bool.self, at: "exact")) ?? false
            var query = Headword
                .query(on: req.db)
                .with(\.$dictionary)
                .join(parent: \.$dictionary)
                .join(from: Dictionary.self, siblings: \.$owners)
            if exact {
                query = query.group(.or) {
                    $0.filter(all: katakanaQuery.components(separatedBy: "|").filter { !$0.isEmpty }) { text in
                        \.$text == text
                    }
                }
            } else {
                query = query.filter(\.$text, .custom("LIKE"), modifiedQuery)
            }
            return query.filter(User.self, \.$id == userID)
                .field(\.$headline).field(\.$shortHeadline).field(\.$dictionary.$id).field(\.$entry.$id).field(\.$entryIndex).field(\.$subentryIndex)
                .field(DictionaryOwner.self, \.$order)
                .sort(DictionaryOwner.self, \.$order)
                .sort(\.$headline)
                .unique()
                .paginate(for: req)
                .map { page in
                    let items = page.items.map { Headword.Simple(headword: $0) }
                    return Page(items: items, metadata: page.metadata)
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

        func outputEntry(text rawText: String, dictionary: Dictionary, forceHorizontalText: Bool, forceDarkCSS: Bool) -> String {
            var text = rawText
            var css = dictionary.css + "\n" + (forceDarkCSS ? dictionary.darkCSS : "")
            var cssWordMappings = [String: String]()
            let directoryName = dictionary.directoryName
            if !directoryName.isEmpty {
                css = DictionaryManager.shared.cssStrings[directoryName]!
                cssWordMappings = DictionaryManager.shared.cssWordMappings[directoryName]!
            } else {
                cssWordMappings = css.replaceNonASCIICharacters()
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
                body {
                    color: \(forceDarkCSS ? "white" : "black") !important;
                }
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

        dictionary.get("entry", ":id") { (req: Request) -> EventLoopFuture<String> in
            let id = try req.parameters.require("id", as: UUID.self)
            let forceHorizontalText = (try? req.query.get(Bool.self, at: "forceHorizontalText")) ?? false
            let forceDarkCSS = (try? req.query.get(Bool.self, at: "forceDarkCSS")) ?? false
            return Entry
                .query(on: req.db)
                .with(\.$dictionary)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMapThrowing { entry in
                    let text = entry.content
                    return outputEntry(text: text, dictionary: entry.dictionary, forceHorizontalText: forceHorizontalText, forceDarkCSS: forceDarkCSS)
                }
        }

        dictionary.get("entry", ":id", ":entryIndex") { (req: Request) -> EventLoopFuture<String> in
            let id = try req.parameters.require("id", as: UUID.self)
            let entryIndex = try req.parameters.require("entryIndex", as: Int.self)
            let forceHorizontalText = (try? req.query.get(Bool.self, at: "forceHorizontalText")) ?? false
            let forceDarkCSS = (try? req.query.get(Bool.self, at: "forceDarkCSS")) ?? false
            return Dictionary.query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMapThrowing { dictionary in
                    guard let contentIndex = DictionaryManager.shared.contentIndexes[dictionary.directoryName] else {
                        throw Abort(.notFound)
                    }
                    guard let realEntryIndex = contentIndex.indexMapping[entryIndex] else {
                        throw Abort(.notFound)
                    }
                    guard let container = DictionaryManager.shared.containers[dictionary.directoryName] else {
                        throw Abort(.notFound)
                    }
                    let text = container.files[realEntryIndex].text
                    return outputEntry(text: text, dictionary: dictionary, forceHorizontalText: forceHorizontalText, forceDarkCSS: forceDarkCSS)
                }
        }

        dictionary.post("status", ":word", ":status") { (req: Request) -> EventLoopFuture<Response> in
            let user = try req.auth.require(User.self)
            let word = try req.parameters.require("word", as: String.self)
            let statusString = try req.parameters.require("status", as: String.self)
            guard let status = Word.Status(rawValue: statusString) else {
                throw Abort(.badRequest, reason: "Invalid status.")
            }

            var words = user.words ?? []
            words.removeAll(where: { $0.word == word })
            words.append(Word(word: word, status: status))
            user.words = words
            return user.save(on: req.db).map { Response(status: .ok) }
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

            let nonLearningWords = (user.words ?? []).filter { $0.status != .learning }
            let inputData = nonLearningWords.map { word -> [Double] in
                let rank = DictionaryManager.shared.frequencyList[word.word]?.numberOfTimes ?? 0
                let difficultyRank = DictionaryManager.shared.difficultyList[word.word]?.difficultyRank ?? 3
                let numberOfKanji = word.word.kanjiCount
                return [
                    Double(rank),
                    Double(difficultyRank),
                    Double(numberOfKanji)
                ]
            }
            let outputData = nonLearningWords.map { $0.status }

            let bayesian = try NaiveBayes(type: .gaussian, data: inputData, classes: outputData).train()

            let listWordsFuture = includeListWords
                ? user.$listWords.query(on: req.db).all()
                : req.eventLoop.future([])
            
            var sentences = try Sentence.parseMultiple(tokenizer: .init(nodes: nodes))

            for (sentenceOffset, sentence) in sentences.enumerated() {
                for (accentPhraseOffset, accentPhrase) in sentence.accentPhrases.enumerated() {
                    for (componentOffset, component) in accentPhrase.components.enumerated() {
                        let word = component.frequencySurface ?? component.surface
                        let rank = DictionaryManager.shared.frequencyList[word]?.numberOfTimes ?? 0
                        let difficultyRank = DictionaryManager.shared.difficultyList[word]?.difficultyRank ?? 3
                        let numberOfKanji = word.kanjiCount
                        let inputData: [Double] = [
                            Double(rank),
                            Double(difficultyRank),
                            Double(numberOfKanji)
                        ]

                        sentences[sentenceOffset].accentPhrases[accentPhraseOffset].components[componentOffset].status = (user.words ?? []).first { $0.word == word }?.status ?? bayesian.classify(with: inputData) ?? .unknown
                        sentences[sentenceOffset].accentPhrases[accentPhraseOffset].components[componentOffset].frequencySurface = word
                    }
                }
            }

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
