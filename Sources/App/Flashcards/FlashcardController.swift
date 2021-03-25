import Fluent
import FluentSQLiteDriver
import ZIPFoundation
import Vapor

class FlashcardController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let flashcards = routes.grouped("flashcard")

        let guardedFlashcards = flashcards
            .grouped(User.guardMiddleware())

        guardedFlashcards.get("numberOfReviews") { req -> EventLoopFuture<Int> in
            let user = try req.auth.require(User.self)
            let now = Date()
            return user.$decks
                .query(on: req.db)
                .all()
                .map { $0.map { $0.sm.queue.filter { $0.dueDate <= now }.count }.reduce(0, +) }
        }

        struct GroupedLogs: Content {
            let count: Int
            let groupDate: Date
        }
        guardedFlashcards.get("groupedLogs") { req -> EventLoopFuture<[GroupedLogs]> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let db = req.db as? SQLDatabase else {
                throw Abort(.internalServerError)
            }
            return db.select()
                .column(SQLFunction("count", args: SQLLiteral.all))
                .column("group_date")
                .from(ReviewLog.schema)
                .join(Card.schema, on: "\(Card.schema).id=\(ReviewLog.schema).card_id")
                .join(Deck.schema, on: "\(Deck.schema).id=\(Card.schema).deck_id AND \(Deck.schema).owner_id='\(userID.uuidString)'")
                .groupBy("group_date")
                .all()
                .flatMapThrowing {
                    try $0.map {
                        try $0.decode(model: GroupedLogs.self, keyDecodingStrategy: .convertFromSnakeCase)
                    }
                }
        }

        struct ReviewsGroupedByGrade: Content {
            let count: Int
            let grade: Double
        }
        guardedFlashcards.get("numberOfReviewsGroupedByGrade") { req -> EventLoopFuture<[ReviewsGroupedByGrade]> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let db = req.db as? SQLDatabase else {
                throw Abort(.internalServerError)
            }
            return db.select()
                .column(SQLFunction("count", args: SQLLiteral.all))
                .column("grade")
                .from(ReviewLog.schema)
                .join(Card.schema, on: "\(Card.schema).id=\(ReviewLog.schema).card_id")
                .join(Deck.schema, on: "\(Deck.schema).id=\(Card.schema).deck_id AND \(Deck.schema).owner_id='\(userID.uuidString)'")
                .groupBy("grade")
                .orderBy("grade")
                .all()
                .flatMapThrowing {
                    try $0.map {
                        try $0.decode(model: ReviewsGroupedByGrade.self, keyDecodingStrategy: .convertFromSnakeCase)
                    }
                }
        }

        // MARK: Card
        let guardedCard = guardedFlashcards.grouped("card")
        let guardedCardID = guardedCard.grouped(":cardID")

        guardedCardID.get { req -> EventLoopFuture<Card> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("cardID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            return Card
                .query(on: req.db)
                .with(\.$deck) {
                    $0.with(\.$owner)
                }
                .with(\.$note) {
                    $0.with(\.$fieldValues) {
                        $0.with(\.$field)
                    }
                }
                .with(\.$cardType)
                .filter(\.$id == id)
                .first()
                .flatMap { card -> EventLoopFuture<Card> in
                    if let card = card {
                        return req.eventLoop.future(card)
                    }

                    return user.$decks
                        .query(on: req.db)
                        .all()
                        .flatMap { decks in
                            for deck in decks {
                                let sm = deck.sm
                                sm.queue.removeAll(where: { $0.card == id })
                                deck.sm = sm
                            }
                            let save = decks.map { $0.save(on: req.db) }
                            return EventLoopFuture.whenAllComplete(save, on: req.eventLoop)
                                .throwingFlatMap { _ in
                                    throw Abort(.notFound)
                                }
                        }
                }
                .guard({ $0.deck.owner.id == userID }, else: Abort(.unauthorized))
        }

        guardedCardID.post("grade", ":grade") { req -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("cardID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let grade = req.parameters.get("grade", as: Double.self) else { throw Abort(.badRequest, reason: "Grade not provided") }
            return Card
                .query(on: req.db)
                .with(\.$deck) {
                    $0.with(\.$owner)
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
                .guard({ $0.deck.owner.id == userID }, else: Abort(.unauthorized))
                .throwingFlatMap { card in
                    let deck = card.deck
                    let sm = deck.sm
                    guard var nextItem = sm.queue.first(where: { $0.card == card.id }), nextItem.dueDate < Date() else {
                        throw Abort(.badRequest)
                    }
                    sm.answer(grade: grade, item: &nextItem)
                    deck.sm = sm
                    return deck.save(on: req.db)
                        .throwingFlatMap {
                            try ReviewLog(card: card, grade: grade)
                                .save(on: req.db)
                        }
                }
                .map { "Updated grade." }
        }

        // MARK: Notes
        let guardedNote = guardedFlashcards.grouped("note")
        let guardedNoteID = guardedNote.grouped(":noteID")
        let guardedNotes = guardedFlashcards.grouped("notes")

        guardedNoteID.delete() { (req: Request) -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("noteID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return Note
                .query(on: req.db)
                .with(\.$fieldValues)
                .with(\.$cards) {
                    $0.with(\.$deck)
                }
                .join(NoteType.self, on: \Note.$noteType.$id == \NoteType.$id)
                .join(User.self, on: \NoteType.$owner.$id == \User.$id)
                .filter(User.self, \.$id == userID)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Note not found"))
                .flatMap { note in
                    let deckUpdates: [EventLoopFuture<Void>] = Swift.Dictionary(grouping: note.cards, by: { $0.deck.id }).map { (id, cards) in
                        let deck = cards.first!.deck
                        let sm = deck.sm
                        let ids = cards.map { $0.id }
                        sm.queue.removeAll(where: { ids.contains($0.card) })
                        deck.sm = sm
                        return deck.update(on: req.db)
                    }
                    return EventLoopFuture.whenAllComplete(deckUpdates, on: req.eventLoop)
                        .flatMap { _ in
                            note.cards.delete(on: req.db)
                                .flatMap {
                                    note.fieldValues.delete(on: req.db)
                                }
                                .flatMap {
                                    note.delete(on: req.db)
                                }
                        }
                }
                .map { "Note deleted." }
        }

        guardedNotes.get() { req -> EventLoopFuture<Page<Note>> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            return Note
                .query(on: req.db)
                .with(\.$noteType) {
                    $0.with(\.$fields)
                }
                .with(\.$fieldValues) {
                    $0.with(\.$field)
                }
                .with(\.$cards)
                .join(NoteType.self, on: \Note.$noteType.$id == \NoteType.$id)
                .join(User.self, on: \NoteType.$owner.$id == \User.$id)
                .filter(User.self, \.$id == userID)
                .paginate(for: req)
        }

        func createNotes(req: Request, values: [(Note.Create, NoteType)], deck: Deck) throws -> EventLoopFuture<[Note]> {
            let futures = try values.map { try createNote(req: req, object: $0.0, noteType: $0.1, deck: deck) }
            return EventLoopFuture.whenAllSucceed(futures, on: req.eventLoop)
        }

        func createNote(req: Request, object: Note.Create, noteType: NoteType, deck: Deck) throws -> EventLoopFuture<Note> {
            let note = Note(noteTypeID: try noteType.requireID())
            return note.create(on: req.db)
                .throwingFlatMap {
                    let fieldValues = try object.fieldValues.map {
                        NoteFieldValue(noteID: try note.requireID(), fieldID: $0.fieldID, value: $0.value)
                    }
                    return note.$fieldValues.create(fieldValues, on: req.db)
                }
                .throwingFlatMap {
                    let allFieldsValue = String(object.fieldValues.flatMap { $0.value })
                    let clozeIndexes = Array(Set(allFieldsValue.match("\\{\\{c(\\d)::.*?\\}\\}").compactMap { Int($0[1]) }))
                    let cards = try noteType.cardTypes.flatMap { cardType  -> [Card] in
                        if clozeIndexes.isEmpty {
                            return [Card(deckID: try deck.requireID(), noteID: try note.requireID(), cardTypeID: try cardType.requireID())]
                        }

                        return try clozeIndexes.map {
                            Card(deckID: try deck.requireID(), noteID: try note.requireID(), cardTypeID: try cardType.requireID(), clozeDeletionIndex: $0)
                        }
                    }
                    return note.$cards.create(cards, on: req.db).throwingFlatMap {
                        Note.query(on: req.db).filter(\.$id == (try! note.requireID())).with(\.$cards).first()
                            .unwrap(orError: Abort(.internalServerError))
                    }
                }
        }

        guardedNote.post() { req -> EventLoopFuture<Note> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()

            try Note.Create.validate(content: req)
            let object = try req.content.decode(Note.Create.self)
            let noteTypeCall = user.$noteTypes
                .query(on: req.db)
                .with(\.$owner)
                .with(\.$cardTypes)
                .filter(\.$id == object.noteTypeID)
                .first()
                .unwrap(or: Abort(.notFound))
                .guard({ $0.owner.id == userID }, else: Abort(.forbidden))

            let deckCall = user.$decks
                .query(on: req.db)
                .with(\.$owner)
                .filter(\.$id == object.targetDeckID)
                .first()
                .unwrap(or: Abort(.notFound))
                .guard({ $0.owner.id == userID }, else: Abort(.forbidden))

            return noteTypeCall.and(deckCall)
                .throwingFlatMap { (noteType, deck) -> EventLoopFuture<Note> in
                    try createNote(req: req, object: object, noteType: noteType, deck: deck)
                        .throwingFlatMap { note in
                            let sm = deck.sm
                            try note.cards.map { try $0.requireID() }.forEach(sm.addItem(card:))
                            deck.sm = sm
                            return deck.save(on: req.db)
                                .flatMap {
                                    var settings = user.settings
                                    settings?.anki.lastUsedDeckID = deck.id
                                    settings?.anki.lastUsedNoteTypeID = noteType.id
                                    user.settings = settings
                                    return user.save(on: req.db)
                                }
                                .map { note }
                        }
                }

        }

        guardedNoteID.post("move", ":deckID") { req -> EventLoopFuture<Note> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("noteID", as: UUID.self) else { throw Abort(.badRequest, reason: "Note ID not provided") }
            guard let deckID = req.parameters.get("deckID", as: UUID.self) else { throw Abort(.badRequest, reason: "Deck ID not provided") }

            let deckCall = user.$decks
                .query(on: req.db)
                .filter(\.$id == deckID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Unable to find deck"))

            return Note
                .query(on: req.db)
                .with(\.$cards) {
                    $0.with(\.$deck)
                }
                .filter(\.$id == id)
                .first()
                .unwrap(or: Abort(.notFound))
                .and(deckCall)
                .throwingFlatMap { note, targetDeck -> EventLoopFuture<Note> in
                    note.$targetDeck.id = targetDeck.id
                    let cardsGroupedByDeck: [[Card]] = Array(Swift.Dictionary(grouping: note.cards, by: { card in
                        card.id
                    }).values)
                    let previousItems = note.cards.compactMap { c in
                        c.deck.sm.queue.first { $0.card == c.id }
                    }

                    // First remove them from their other decks.
                    let futures = cardsGroupedByDeck.compactMap { cards -> EventLoopFuture<Void>? in
                        let oldDeck = cards[0].deck
                        if oldDeck.id == targetDeck.id {
                            return nil
                        }

                        let sm = oldDeck.sm
                        let deletableCardIDs = cards.map { $0.id }
                        sm.queue.removeAll(where: { deletableCardIDs.contains($0.card) })
                        oldDeck.sm = sm
                        return oldDeck.save(on: req.db)
                    }
                    return EventLoopFuture.whenAllSucceed(futures, on: req.eventLoop).throwingFlatMap { _ in
                        let addCards = note.cards.filter { $0.deck.id != targetDeck.id }
                        for card in addCards {
                            card.$deck.id = try targetDeck.requireID()
                        }
                        return EventLoopFuture.whenAllSucceed(addCards.map { $0.save(on: req.db) }, on: req.eventLoop)
                            .throwingFlatMap { _ in
                                let sm = targetDeck.sm
                                for card in addCards {
                                    if let previousItem = previousItems.first(where: { $0.card == card.id }) {
                                        sm.queue.append(previousItem)
                                    } else {
                                        sm.addItem(card: try card.requireID())
                                    }
                                }
                                targetDeck.sm = sm
                                return targetDeck.save(on: req.db)
                            }
                    }
                    .map {
                        note
                    }
                }

        }

        guardedNoteID.put() { req -> EventLoopFuture<Note> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("noteID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try Note.Update.validate(content: req)
            let object = try req.content.decode(Note.Update.self)
            let noteCall = Note
                .query(on: req.db)
                .with(\.$noteType) {
                    $0.with(\.$owner).with(\.$cardTypes)
                }
                .with(\.$cards) {
                    $0.with(\.$deck)
                }
                .with(\.$targetDeck)
                .with(\.$fieldValues)
                .filter(\.$id == id)
                .first()
                .unwrap(or: Abort(.notFound))
                .guard({ $0.noteType.owner.id == userID }, else: Abort(.forbidden))

            return noteCall
                .throwingFlatMap { note -> EventLoopFuture<Note> in
                    guard let deck = note.targetDeck ?? note.cards.first?.deck else {
                        throw Abort(.internalServerError)
                    }
                    let noteType = note.noteType
                    let previousClozeIndexes = note.cards.compactMap { $0.clozeDeletionIndex }
                    for fieldValue in note.fieldValues {
                        let newValue = object.fieldValues.first(where: { $0.id == fieldValue.id })?.value
                        fieldValue.value = newValue ?? ""
                    }

                    return EventLoopFuture<Void>.andAllSucceed(note.fieldValues.map { $0.save(on: req.db) }, on: req.eventLoop)
                        .throwingFlatMap {
                            let allFieldsValue = String(object.fieldValues.flatMap { $0.value })
                            let clozeIndexes = Array(Set(allFieldsValue.match("\\{\\{c(\\d)::.*?\\}\\}").compactMap { Int($0[1]) }))
                            let createClozeIndexes = clozeIndexes.filter { !previousClozeIndexes.contains($0) }
                            let cards = try noteType.cardTypes.flatMap { cardType -> [Card] in
                                if !previousClozeIndexes.isEmpty && clozeIndexes.isEmpty {
                                    // Removed all cloze cards
                                    // Create a regular card
                                    return [Card(deckID: try deck.requireID(), noteID: try note.requireID(), cardTypeID: try cardType.requireID())]
                                }
                                if previousClozeIndexes.isEmpty && clozeIndexes.isEmpty {
                                    // There were never any cloze cards
                                    return []
                                }

                                return try createClozeIndexes.map {
                                    Card(deckID: try deck.requireID(), noteID: try note.requireID(), cardTypeID: try cardType.requireID(), clozeDeletionIndex: $0)
                                }
                            }

                            let deleteClozeIndexes = previousClozeIndexes.filter { !clozeIndexes.contains($0) }
                            let deletableCards = note.cards.filter {
                                // No previous cloze deletion cards but now there
                                // are so remove previous non cloze deletion cards.
                                if previousClozeIndexes.isEmpty && !createClozeIndexes.isEmpty {
                                    return true
                                }
                                guard let i = $0.clozeDeletionIndex else { return false }
                                return deleteClozeIndexes.contains(i)
                            }
                            let deletableCardIDs = deletableCards.map { $0.id }

                            // Delete removed cloze deletion cards
                            return deletableCards.delete(on: req.db).flatMap {
                                // Add newly created cards
                                // TODO: This only deletes things on one deck. In reality things may be contained on separate decks.
                                return note.$cards.create(cards, on: req.db)
                                    .throwingFlatMap {
                                        let sm = deck.sm
                                        try cards.map { try $0.requireID() }.forEach(sm.addItem(card:))
                                        sm.queue.removeAll(where: { deletableCardIDs.contains($0.card) })
                                        deck.sm = sm
                                        return deck.save(on: req.db)
                                    }
                            }
                                .throwingFlatMap {
                                    Note.find(try note.requireID(), on: req.db)
                                        .unwrap(orError: Abort(.internalServerError))
                                }
                        }
                }
        }

        // MARK: Decks

        let guardedDeck = guardedFlashcards.grouped("deck")
        let guardedDeckID = guardedFlashcards.grouped("deck", ":deckID")
        let guardedDecks = guardedFlashcards.grouped("decks")

        guardedDeckID.get { req -> EventLoopFuture<Deck> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("deckID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            return user.$decks
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
        }

        guardedDeckID.put { req -> EventLoopFuture<Deck> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("deckID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            try Deck.Update.validate(content: req)
            let object = try req.content.decode(Deck.Update.self)
            return user.$decks
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
                .flatMap { deck in
                    deck.scheduleOrder = object.scheduleOrder.rawValue
                    deck.newOrder = object.newOrder.rawValue
                    deck.reviewOrder = object.reviewOrder.rawValue

                    let sm = deck.sm
                    sm.requestedFI = Double(object.requestedFI)

                    deck.name = object.name
                    deck.sm = sm
                    return deck.save(on: req.db)
                        .map { deck }
                }
        }

        guardedDecks.get { req -> EventLoopFuture<[Deck]> in
            let user = try req.auth.require(User.self)
            return user.$decks
                .query(on: req.db)
                .all()
                .map { $0.sorted(by: { $0.name > $1.name }) }
        }

        guardedDeck.post("create") { req -> EventLoopFuture<Deck> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()

            try Deck.Create.validate(content: req)
            let object = try req.content.decode(Deck.Create.self)
            let deck = Deck(ownerID: userID, name: object.name, sm: .init())

            return deck
                .save(on: req.db)
                .flatMap {
                    // Default values not getting initialized on first load so
                    // we have to fetch again
                    Deck.find(deck.id, on: req.db).unwrap(or: Abort(.internalServerError))
                }
        }

        guardedDeckID.post("import") { (req: Request) -> EventLoopFuture<[Note]> in
            struct Upload: Content {
                let file: Vapor.File
            }
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("deckID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            let file = try req.content.decode(Upload.self).file
            let data = Data(buffer: file.data)

            let directory = URL(fileURLWithPath: req.application.directory.resourcesDirectory).appendingPathComponent("Temp")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let uuid = UUID().uuidString
            guard let archive = Archive(data: data, accessMode: .read, preferredEncoding: .utf8) else  {
                throw Abort(.badRequest, reason: "Could not open zip archive.")
            }
            guard let entry = archive["collection.anki2"] else {
                throw Abort(.badRequest, reason: "Could not find SQLite database.")
            }
            let destinationURL = directory.appendingPathComponent("\(uuid).sqlite")
            do {
                _ = try archive.extract(entry, to: destinationURL)
            } catch {
                throw Abort(.badRequest, reason: "Extracting entry from archive failed with error: \(error)")
            }

            req.application.databases.use(.sqlite(.file(destinationURL.path)), as: .init(string: uuid))
            let db = req.db(.init(string: uuid))
            let notes = Anki.Note.query(on: db).all()
            let deckCall = user.$decks
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Unable to find deck"))
            return Anki.Collection.query(on: db).first().unwrap(or: Abort(.badRequest, reason: "No collection in Anki database")).and(notes).and(deckCall)
                .throwingFlatMap { values in
                    let collection = values.0.0
                    let notes = values.0.1
                    let deck = values.1
                    let usedModelIDs = Array(Set(notes.map { $0.modelID }))

                    // Create Note Types
                    let prevNoteTypes = collection.models.values.filter { usedModelIDs.contains($0.id) }
                    let noteTypesWithoutCardTypes = prevNoteTypes.map {
                        NoteType(ownerID: userID, name: $0.name, sharedCSS: $0.css)
                    }

                    return noteTypesWithoutCardTypes.create(on: req.db)
                        .throwingFlatMap {
                            // Create Note Card Types
                            let cardTypes = try prevNoteTypes.flatMap { (model: Anki.Model) -> [CardType] in
                                let noteType = noteTypesWithoutCardTypes.first(where: { $0.name == model.name })!
                                let templates = model.tmpls.sorted(by: { $0.ord < $1.ord })
                                return try templates.map { template in
                                    CardType(noteTypeID: try noteType.requireID(), overrideDeckID: nil, name: template.name, frontHTML: template.qfmt, backHTML: template.afmt, css: "")
                                }
                            }

                            return cardTypes.create(on: req.db).throwingFlatMap {
                                let latestNoteTypes = try noteTypesWithoutCardTypes.map { try $0.requireID() }.map { NoteType.query(on: req.db).with(\.$cardTypes).filter(\.$id == $0).first().unwrap(orError: Abort(.badRequest, reason: "Unable to find just saved note type")) }
                                return EventLoopFuture.whenAllSucceed(latestNoteTypes, on: req.eventLoop)
                            }
                        }
                        .throwingFlatMap { (noteTypes: [NoteType]) in
                            // Create Note Fields
                            let fields = try prevNoteTypes.flatMap { (model: Anki.Model) -> [NoteField] in
                                let noteType = noteTypes.first(where: { $0.name == model.name })!
                                let fields = model.flds.sorted(by: { $0.ord < $1.ord })
                                return try fields.map { field in
                                    NoteField(noteTypeID: try noteType.requireID(), name: field.name)
                                }
                            }

                            return fields.create(on: req.db)
                                .throwingFlatMap {
                                    // Create Notes
                                    let values = try notes.map { (note: Anki.Note) -> (Note.Create, NoteType) in
                                        guard let model = prevNoteTypes.first(where: { $0.id == note.modelID }) else {
                                            throw Abort(.badRequest, reason: "Could not find model for note")
                                        }
                                        guard let noteType = noteTypes.first(where: { $0.name == model.name }) else {
                                            throw Abort(.badRequest, reason: "Could not find note type for model")
                                        }
                                        let divider = String(UnicodeScalar(UInt8(31)))
                                        let rawFieldValues = note.fields.components(separatedBy: divider)
                                        let modelFields = model.flds.sorted(by: { $0.ord < $1.ord })
                                        guard rawFieldValues.count == modelFields.count else {
                                            throw Abort(.badRequest, reason: "Count of note fields does not match count of model fields")
                                        }
                                        let fieldValues = try modelFields.enumerated().map { (i, modelField) -> NoteFieldValue.Create in
                                            guard let field = fields.first(where: { $0.$noteType.id == noteType.id && $0.name == modelField.name }) else {
                                                throw Abort(.badRequest, reason: "Could not find field for note.")
                                            }

                                            return NoteFieldValue.Create(fieldID: try field.requireID(), value: String(rawFieldValues[i]))
                                        }

                                        let note = Note.Create(targetDeckID: id, noteTypeID: try noteType.requireID(), fieldValues: fieldValues)
                                        return (note, noteType)
                                    }
                                    return try createNotes(req: req, values: values, deck: deck)
                                        .throwingFlatMap { notes in
                                            let sm = deck.sm
                                            let cards = notes.flatMap { $0.cards }
                                            try cards.map { try $0.requireID() }.forEach(sm.addItem(card:))
                                            deck.sm = sm
                                            return deck.save(on: req.db)
                                                .map { notes }
                                        }
                                }
                        }
                }
        }

        guardedDeckID.delete() { (req: Request) -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("deckID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user.$decks
                .query(on: req.db)
                .with(\.$cards) {
                    $0.with(\.$note) {
                        $0.with(\.$cards).with(\.$fieldValues)
                    }
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Deck not found"))
                .flatMap { deck in
                    let cards = deck.cards
                    return deck.cards.delete(on: req.db)
                        .flatMap {
                            let notes = Array(Set(cards.map { $0.note }))
                            let deletableNotes = notes.filter { note in note.cards.filter { card in !cards.contains(where: { $0.id == card.id}) }.isEmpty }
                            let fieldValues = deletableNotes.flatMap { $0.fieldValues }
                            return fieldValues.delete(on: req.db).flatMap {
                                return deletableNotes.delete(on: req.db)
                            }
                        }
                        .flatMap {
                            deck.delete(on: req.db)
                        }
                }
                .map { "Deck deleted." }
        }

        // MARK: Note Types

        let guardedNoteType = guardedFlashcards.grouped("noteType")
        let guardedNoteTypeID = guardedFlashcards.grouped("noteType", ":noteTypeID")
        let guardedNoteTypes = guardedFlashcards.grouped("noteTypes")

        guardedNoteTypes.get { req -> EventLoopFuture<[NoteType]> in
            let user = try req.auth.require(User.self)
            return user.$noteTypes
                .query(on: req.db)
                .with(\.$fields)
                .all()
                .map { $0.sorted(by: { $0.name > $1.name }) }
        }

        guardedNoteType.post("create") { req -> EventLoopFuture<NoteType> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()

            try NoteType.Create.validate(content: req)
            let object = try req.content.decode(NoteType.Create.self)
            let noteType = NoteType(ownerID: userID, name: object.name)

            return noteType
                .save(on: req.db)
                .throwingFlatMap {
                    let fields = [
                        NoteField(noteTypeID: try noteType.requireID(), name: "Front"),
                        NoteField(noteTypeID: try noteType.requireID(), name: "Back")
                    ]
                    return fields.create(on: req.db)
                }
                .throwingFlatMap {
                    let basicCardType = CardType(noteTypeID: try noteType.requireID(), overrideDeckID: nil, name: "Simple", frontHTML: "{{Front}}", backHTML: "{{FrontSide}}<hr/>{{Back}}", css: "")
                    return basicCardType.create(on: req.db)
                }
                .map { noteType }
        }

        guardedNoteTypeID.get() { req -> EventLoopFuture<NoteType> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("noteTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user.$noteTypes
                .query(on: req.db)
                .with(\.$fields)
                .with(\.$cardTypes)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.notFound))
        }

        guardedNoteTypeID.delete() { (req: Request) -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("noteTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user.$noteTypes
                .query(on: req.db)
                .with(\.$cardTypes)
                .with(\.$fields)
                .with(\.$notes) {
                    $0.with(\.$fieldValues).with(\.$cards) {
                        $0.with(\.$deck)
                    }
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Note type not found"))
                .flatMap { type in
                    let cards = type.notes.flatMap { $0.cards }
                    let fieldValues = type.notes.flatMap { $0.fieldValues }
                    let deckUpdates: [EventLoopFuture<Void>] = Swift.Dictionary(grouping: cards, by: { $0.deck.id }).map { (id, cards) in
                        let deck = cards.first!.deck
                        let sm = deck.sm
                        let ids = cards.map { $0.id }
                        sm.queue.removeAll(where: { ids.contains($0.card) })
                        deck.sm = sm
                        return deck.update(on: req.db)
                    }
                    return EventLoopFuture.whenAllComplete(deckUpdates, on: req.eventLoop)
                        .flatMap { _ in
                            cards.delete(on: req.db)
                                .flatMap {
                                    fieldValues.delete(on: req.db)
                                }
                                .flatMap {
                                    type.notes.delete(on: req.db)
                                }
                        }
                        .flatMap {
                            type.cardTypes.delete(on: req.db)
                        }
                        .flatMap {
                            type.fields.delete(on: req.db)
                        }
                        .flatMap {
                            type.delete(on: req.db)
                        }
                }
                .map { "Note type deleted." }
        }

        // MARK: Fields

        let guardedField = guardedNoteTypeID.grouped("field")

        guardedField.post() { req -> EventLoopFuture<NoteField> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("noteTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try NoteField.Create.validate(content: req)
            let object = try req.content.decode(NoteField.Create.self)

            return user.$noteTypes
                .query(on: req.db)
                .filter(\.$id == id)
                .with(\.$notes)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Note type not found"))
                .throwingFlatMap { type in
                    let field = NoteField(noteTypeID: try type.requireID(), name: object.name)
                    return type.$fields.create(field, on: req.db)
                        .throwingFlatMap {
                            let fieldValues = try type.notes.map {
                                NoteFieldValue(noteID: try $0.requireID(), fieldID: try field.requireID(), value: "")
                            }
                            return fieldValues.create(on: req.db)
                        }
                        .map {
                            field
                        }
                }
        }

        guardedField.delete(":fieldID") { req -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let typeID = req.parameters.get("noteTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let fieldID = req.parameters.get("fieldID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return NoteField.query(on: req.db)
                .with(\.$values)
                .with(\.$noteType) {
                    $0.with(\.$owner)
                }
                .filter(\.$id == fieldID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Note field not found"))
                .guard({ $0.noteType.owner.id == userID && $0.$noteType.id == typeID }, else: Abort(.badRequest))
                .flatMap { field in
                    field.values.delete(on: req.db)
                        .flatMap {
                            field.delete(on: req.db)
                        }
                }
                .map { "Note field deleted." }
        }

        // MARK: Card Types

        let guardedCardType = guardedNoteTypeID.grouped("cardType")
        let guardedCardTypeID = guardedCardType.grouped(":cardTypeID")

        guardedCardType.post() { req -> EventLoopFuture<CardType> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("noteTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try CardType.Create.validate(content: req)
            let object = try req.content.decode(CardType.Create.self)

            return user.$noteTypes
                .query(on: req.db)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Note type not found"))
                .throwingFlatMap { type in
                    let cardType = CardType(noteTypeID: try type.requireID(), overrideDeckID: nil, name: object.name, frontHTML: "", backHTML: "", css: "")
                    return type.$cardTypes.create(cardType, on: req.db)
                        .map { cardType }
                }
        }

        guardedCardTypeID.put() { (req: Request) -> EventLoopFuture<CardType> in
            let user = req.auth.get(User.self) ?? User.guest
            let userID = try user.requireID()
            guard let noteTypeID = req.parameters.get("noteTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "Note Type ID not provided") }
            guard let cardTypeID = req.parameters.get("cardTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "Card Type ID not provided") }

            try CardType.Update.validate(content: req)
            let object = try req.content.decode(CardType.Update.self)
            return CardType.query(on: req.db)
                .with(\.$noteType) {
                    $0.with(\.$owner)
                }
                .filter(\.$id == cardTypeID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Card type not found"))
                .guard({ $0.noteType.owner.id == userID }, else: Abort(.unauthorized, reason: "You are not authorized to view this card type"))
                .guard({ $0.noteType.id == noteTypeID }, else: Abort(.unauthorized, reason: "Card type does not belong to this note type"))
                .flatMap { cardType in
                    cardType.frontHTML = object.frontHTML
                    cardType.backHTML = object.backHTML
                    cardType.css = object.css
                    cardType.$overrideDeck.id = object.overrideDeckID
                    cardType.name = object.name
                    return cardType.update(on: req.db)
                        .map { cardType }
                }
        }

    }

}
