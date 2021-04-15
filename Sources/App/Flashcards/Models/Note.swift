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

    @Field(key: "tags")
    var tags: [String]

    @Parent(key: "note_type_id")
    var noteType: NoteType

    @OptionalParent(key: "target_deck_id")
    var targetDeck: Deck?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Children(for: \.$note)
    var fieldValues: [NoteFieldValue]

    @Children(for: \.$note)
    var cards: [Card]

    init() { }

    init(id: UUID? = nil, noteTypeID: UUID, tags: [String]) {
        self.id = id
        self.$noteType.id = noteTypeID
        self.tags = tags
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

    struct Migration2: Fluent.Migration {
        var name: String { "CreateNoteParentDeck" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("target_deck_id", .uuid, .references("flashcard_decks", "id"))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("target_deck_id")
                .update()
        }
    }

    struct Migration3: Fluent.Migration {
        var name: String { "CreateNoteTags" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("tags", .array(of: .string), .required, .sql(.default("{}")))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("tags")
                .update()
        }
    }

}

extension Note {

    struct Create: Content {
        let targetDeckID: UUID
        let noteTypeID: UUID
        let fieldValues: [NoteFieldValue.Create]
        let tags: [String]
    }

    struct Update: Content {
        let fieldValues: [NoteFieldValue.Update]
        let tags: [String]
    }

}

extension Note.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("targetDeckID", as: UUID.self)

        validations.add("noteTypeID", as: UUID.self)
        validations.add("fieldValues", as: [NoteFieldValue.Create].self)
        validations.add("tags", as: [String].self)
    }

}

extension Note.Update: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("fieldValues", as: [NoteFieldValue.Update].self)
        validations.add("tags", as: [String].self)
    }

}
