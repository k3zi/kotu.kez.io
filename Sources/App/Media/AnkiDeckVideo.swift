import Fluent
import Vapor

final class AnkiDeckVideo: Model, Content {

    static let schema = "anki_deck_videos"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Children(for: \.$video)
    var subtitles: [AnkiDeckSubtitle]

    init() { }

    init(id: UUID? = nil, title: String) {
        self.id = id
        self.title = title
    }

}

extension AnkiDeckVideo {

    struct Migration: Fluent.Migration {
        var name: String { "CreateAnkiDeckVideo" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("title", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}


