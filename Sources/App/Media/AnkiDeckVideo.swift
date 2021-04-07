import Fluent
import Vapor

final class AnkiDeckVideo: Model, Content {

    static let schema = "anki_deck_videos"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "source")
    var source: String

    @Field(key: "tags")
    var tags: [String]

    @Children(for: \.$video)
    var subtitles: [AnkiDeckSubtitle]

    @Children(for: \.$media)
    var readerSessions: [ReaderSession]

    init() { }

    init(id: UUID? = nil, title: String, source: String = "anki", tags: [String] = [], startTime: Double? = nil, endTime: Double? = nil) {
        self.id = id
        self.title = title
        self.source = source
        self.tags = tags
    }

}

extension AnkiDeckVideo {

    struct Update: Content, Validatable {
        let title: String

        static func validations(_ validations: inout Validations) {
            validations.add("title", as: String.self, is: !.empty)
        }
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

    struct Migration1: Fluent.Migration {
        var name: String { "AnkiDeckVideoSource" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("source", .string, .required, .sql(.default("anki")))
                .field("tags", .array(of: .string))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("source")
                .deleteField("tags")
                .update()
        }
    }

    struct Migration2: Fluent.Migration {
        var name: String { "AnkiDeckVideoSource1" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("tags")
                .field("tags", .array(of: .string), .required, .sql(.default("{}")))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .update()
        }
    }

}


