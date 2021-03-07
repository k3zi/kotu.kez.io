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

    init() { }

    init(id: UUID? = nil, video: AnkiDeckVideo, text: String, externalFile: ExternalFile) {
        self.id = id
        self.$video.id = try! video.requireID()
        self.$externalFile.id = try! externalFile.requireID()
        self.text = text
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

}

