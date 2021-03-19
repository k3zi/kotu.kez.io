import Fluent
import Vapor

final class AnkiDeckSubtitle: Model, Content {

    static let schema = "anki_deck_subtitles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "video_id")
    var video: AnkiDeckVideo

    @Parent(key: "external_file_id")
    var externalFile: ExternalFile

    @Field(key: "text")
    var text: String

    @OptionalField(key: "start_time")
    var startTime: Double?

    @OptionalField(key: "end_time")
    var endTime: Double?

    init() { }

    init(id: UUID? = nil, video: AnkiDeckVideo, text: String, externalFile: ExternalFile, startTime: Double? = nil, endTime: Double? = nil) {
        self.id = id
        self.$video.id = try! video.requireID()
        self.$externalFile.id = try! externalFile.requireID()
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }

}

extension AnkiDeckSubtitle {

    struct Migration: Fluent.Migration {
        var name: String { "CreateAnkiDeckSubtitle" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("video_id", .uuid, .required, .references("anki_deck_videos", "id"))
                .field("external_file_id", .uuid, .required, .references("external_files", "id"))
                .field("text", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "AnkiDeckSubtitleTiming" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("start_time", .double)
                .field("end_time", .double)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("start_time")
                .deleteField("end_time")
                .update()
        }
    }

}

