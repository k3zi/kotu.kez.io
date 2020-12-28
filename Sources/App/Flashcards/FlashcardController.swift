import Fluent
import Vapor

class FlashcardController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let flashcards = routes.grouped("flashcard")

        let guardedFlashcards = flashcards
            .grouped(User.guardMiddleware())

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
                .unwrap(orError: Abort(.notFound))
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
                    guard var nextItem = sm.nextItem(), nextItem.card == card.id else {
                        throw Abort(.badRequest)
                    }
                    sm.answer(grade: grade, item: &nextItem)
                    deck.sm = sm
                    return deck.save(on: req.db)
                }
                .map { "Updated grade." }
        }

        // MARK: Notes
        let guardedNote = guardedFlashcards.grouped("note")

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
                    let note = Note(noteTypeID: try noteType.requireID())
                    return note.create(on: req.db)
                        .throwingFlatMap {
                            let fieldValues = try object.fieldValues.map {
                                NoteFieldValue(noteID: try note.requireID(), fieldID: $0.fieldID, value: $0.value)
                            }
                            return note.$fieldValues.create(fieldValues, on: req.db)
                        }
                        .throwingFlatMap {
                            let cards = try noteType.cardTypes.map {
                                Card(deckID: try deck.requireID(), noteID: try note.requireID(), cardTypeID: try $0.requireID())
                            }
                            return note.$cards.create(cards, on: req.db)
                                .throwingFlatMap {
                                    let sm = deck.sm
                                    try cards.map { try $0.requireID() }.forEach(sm.addItem(card:))
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
                .map { deck }
        }

        guardedDeckID.delete() { (req: Request) -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("deckID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user.$decks
                .query(on: req.db)
                .with(\.$cards)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Deck not found"))
                .flatMap { deck in
                    deck.cards.delete(on: req.db)
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
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Note type not found"))
                .flatMap { type in
                    type.delete(on: req.db)
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
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Note type not found"))
                .throwingFlatMap { type in
                    let field = NoteField(noteTypeID: try type.requireID(), name: object.name)
                    return type.$fields.create(field, on: req.db)
                        .map { field }
                }
        }

        guardedField.delete(":fieldID") { req -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let typeID = req.parameters.get("noteTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }
            guard let fieldID = req.parameters.get("fieldID", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return NoteField.query(on: req.db)
                .with(\.$noteType) {
                    $0.with(\.$owner)
                }
                .filter(\.$id == fieldID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Note field not found"))
                .guard({ $0.noteType.owner.id == userID && $0.$noteType.id == typeID }, else: Abort(.badRequest))
                .flatMap { field in
                    field.delete(on: req.db)
                }
                .map { "Note field deleted." }
        }

        // MARK: Card Types

        let guardedCardType = guardedNoteTypeID.grouped("cardType")
        let guardedCardTypeID = guardedCardType.grouped(":cardTypeID")

        guardedCardTypeID.put() { (req: Request) -> EventLoopFuture<CardType> in
            let user = req.auth.get(User.self) ?? User.guest
            let userID = try user.requireID()
            guard let noteTypeID = req.parameters.get("noteTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "Note Type ID not provided") }
            guard let cardTypeID = req.parameters.get("cardTypeID", as: UUID.self) else { throw Abort(.badRequest, reason: "Card Type ID not provided") }

            try CardType.CreateOrUpdate.validate(content: req)
            let object = try req.content.decode(CardType.CreateOrUpdate.self)
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
