import Fluent
import Vapor

/// The value of a note field for a specific note.
final class NoteFieldValue: Model, Content {

    static let schema = "flashcard_note_field_values"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "note_id")
    var note: Note

    @Parent(key: "field_id")
    var field: NoteField

    @Field(key: "value")
    var value: String

    init() { }

    init(id: UUID? = nil, noteID: UUID, fieldID: UUID, value: String) {
        self.id = id
        self.$note.id = noteID
        self.$field.id = fieldID
        self.value = value
    }

}

extension NoteFieldValue {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFlashcardNoteFieldValue" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("note_id", .uuid, .required, .references("flashcard_notes", "id"))
                .field("field_id", .uuid, .required, .references("flashcard_note_fields", "id"))
                .field("value", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}

extension NoteFieldValue {

    struct Create: Content {
        let fieldID: UUID
        let value: String
    }

}

extension NoteFieldValue.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("fieldID", as: UUID.self)
        validations.add("value", as: String.self, is: !.empty)
    }

}

