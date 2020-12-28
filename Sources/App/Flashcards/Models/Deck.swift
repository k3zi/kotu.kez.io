import Fluent
import Vapor

final class Deck: Model, Content {

    static let schema = "flashcard_decks"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "name")
    var name: String

    // The UUID of the individual `Card`s is used.
    @Field(key: "sweet_memo")
    var sm: SweetMemo

    @Children(for: \.$deck)
    var cards: [Card]

    init() { }

    init(id: UUID? = nil, ownerID: UUID, name: String, sm: SweetMemo) {
        self.id = id
        self.$owner.id = ownerID
        self.name = name
        self.sm = sm
    }

}

extension Deck {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFlashcardDeck" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .field("name", .string, .required)
                .field("sweet_memo", .json, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}

extension Deck {

    struct Create: Content {
        let name: String
    }

}

extension Deck.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
    }

}
