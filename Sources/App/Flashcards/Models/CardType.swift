import Fluent
import Vapor

/// Encapsulate a template for flashcards with a front and back. These generate Cards and are stored under
/// their parent note types.
final class CardType: Model, Content {

    static let schema = "flashcard_card_types"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "note_type_id")
    var noteType: NoteType

    @OptionalParent(key: "override_deck_id")
    var overrideDeck: Deck?

    @Field(key: "name")
    var name: String

    @Field(key: "front_html")
    var frontHTML: String

    @Field(key: "back_html")
    var backHTML: String

    @Field(key: "css")
    var css: String

    init() { }

    init(id: UUID? = nil, noteTypeID: UUID, overrideDeckID: UUID?, name: String, frontHTML: String, backHTML: String, css: String) {
        self.id = id
        self.$noteType.id = noteTypeID
        self.$overrideDeck.id = overrideDeckID
        self.name = name
        self.frontHTML = frontHTML
        self.backHTML = backHTML
        self.css = css
    }

}

extension CardType {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFlashcardCardType" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("note_type_id", .uuid, .required, .references("flashcard_note_types", "id"))
                .field("override_deck_id", .uuid, .references("flashcard_decks", "id"))
                .field("name", .string, .required)
                .field("front_html", .string, .required)
                .field("back_html", .string, .required)
                .field("css", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}

extension CardType {

    struct Create: Content {
        let name: String
    }

    struct Update: Content {
        let overrideDeckID: UUID?
        let name: String
        let frontHTML: String
        let backHTML: String
        let css: String
    }

}

extension CardType.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
    }

}

extension CardType.Update: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("frontHTML", as: String.self)
        validations.add("backHTML", as: String.self)
        validations.add("css", as: String.self)
    }

}
