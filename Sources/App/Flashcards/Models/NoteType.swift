import Fluent
import Vapor

final class NoteType: Model, Content {

    static let schema = "flashcard_note_types"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "name")
    var name: String

    @Children(for: \.$noteType)
    var fields: [NoteField]

    @Children(for: \.$noteType)
    var cardTypes: [CardType]

    @Children(for: \.$noteType)
    var notes: [Note]

    @Field(key: "shared_css")
    var sharedCSS: String

    init() { }

    init(id: UUID? = nil, ownerID: UUID, name: String, sharedCSS: String = "") {
        self.id = id
        self.$owner.id = ownerID
        self.name = name
        self.sharedCSS = sharedCSS
    }

}

extension NoteType {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFlashcardNoteType" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .field("name", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "UpdateFlashcardNoteTypeSharedCSS" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("shared_css", .string, .required, .sql(.default("")))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("shared_css")
                .update()
        }
    }

}

extension NoteType {

    struct Create: Content {
        let name: String
    }

}

extension NoteType.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
    }

}
