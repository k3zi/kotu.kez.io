import Fluent
import Vapor

/// A collection of field values that generate one or more cards.
final class Note: Model, Content, Hashable {

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let schema = "flashcard_notes"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "note_type_id")
    var noteType: NoteType

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$note)
    var fieldValues: [NoteFieldValue]

    @Children(for: \.$note)
    var cards: [Card]

    init() { }

    init(id: UUID? = nil, noteTypeID: UUID) {
        self.id = id
        self.$noteType.id = noteTypeID
    }

}

extension Note {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFlashcardNote" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("note_type_id", .uuid, .required, .references("flashcard_note_types", "id"))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateNoteCreatedAt" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("created_at", .date)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("created_at")
                .update()
        }
    }

}

extension Note {

    struct Create: Content {
        let targetDeckID: UUID

        let noteTypeID: UUID
        let fieldValues: [NoteFieldValue.Create]
    }

}

extension Note.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("targetDeckID", as: UUID.self)

        validations.add("noteTypeID", as: UUID.self)
        validations.add("fieldValues", as: [NoteFieldValue.Create].self)
    }

}
