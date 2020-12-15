import Fluent
import Vapor

final class Subtitle: Model, Content {

    static let schema = "transcription_subtitles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "translation_id")
    var translation: Translation

    @Field(key: "start_time")
    var startTime: Double

    @Field(key: "end_time")
    var endTime: Double

    @Field(key: "text")
    var text: String

    init() { }

    init(id: UUID? = nil, translationID: UUID, startTime: Double, endTime: Double, text: String) {
        self.id = id
        self.$translation.id = translationID
        self.startTime = startTime
        self.endTime = endTime
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

}
