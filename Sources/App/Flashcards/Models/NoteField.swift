import Fluent
import Vapor

/// The available fields under a note type.
final class NoteField: Model, Content {

    static let schema = "flashcard_note_fields"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "note_type_id")
    var noteType: NoteType

    @Field(key: "name")
    var name: String

    @Children(for: \.$field)
    var values: [NoteFieldValue]

    init() { }

    init(id: UUID? = nil, noteTypeID: UUID, name: String) {
        self.id = id
        self.$noteType.id = noteTypeID
        self.name = name
    }

}

extension NoteField {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFlashcardNoteField" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("note_type_id", .uuid, .required, .references("flashcard_note_types", "id"))
                .field("name", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}

extension NoteField {

    struct Create: Content {
        let name: String
    }

}

extension NoteField.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
    }

}

