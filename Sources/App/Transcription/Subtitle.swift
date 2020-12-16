import Fluent
import Vapor

final class Subtitle: Model, Content {

    static let schema = "transcription_subtitles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "translation_id")
    var translation: Translation

    @Parent(key: "fragment_id")
    var fragment: Fragment

    @Field(key: "text")
    var text: String

    init() { }

    init(id: UUID? = nil, translationID: UUID, fragmentID: UUID, text: String) {
        self.id = id
        self.$translation.id = translationID
        self.$fragment.id = fragmentID
        self.text = text
    }

}

extension Subtitle {

    struct Migration: Fluent.Migration {
        var name: String { "CreateTranscriptionSubtitle" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("translation_id", .uuid, .required, .references("transcription_translations", "id"))
                .field("start_time", .double, .required)
                .field("end_time", .double, .required)
                .field("text", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "TranscriptionSubtitleFragment" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("fragment_id", .uuid, .required, .references("transcription_fragments", "id"))
                .deleteField("start_time")
                .deleteField("end_time")
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("fragment_id")
                .field("start_time", .double, .required)
                .field("end_time", .double, .required)
                .update()
        }
    }

}

extension Subtitle {

    struct Create: Content {
        let translationID: UUID
        let fragmentID: UUID
        let text: String
    }

}

extension Subtitle.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("translationID", as: UUID.self)
        validations.add("fragmentID", as: UUID.self)
        validations.add("text", as: String.self, is: !.empty)
    }

}

extension Subtitle {

    struct Update: Content {
        let text: String
    }

}

extension Subtitle.Update: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("text", as: String.self, is: !.empty)
    }

}
