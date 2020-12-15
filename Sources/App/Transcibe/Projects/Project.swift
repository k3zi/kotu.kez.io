import Fluent
import Vapor

final class Project: Model, Content {

    static let schema = "transcription_projects"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "youtube_id")
    var youtubeID: String

    @Children(for: \.$project)
    var translations: [Translation]

    init() { }

    init(id: UUID? = nil, name: String, youtubeID: String) {
        self.id = id
        self.name = name
        self.youtubeID = youtubeID
    }

}

extension Project {

    struct Migration: Fluent.Migration {
        var name: String { "CreateTranscribeProject" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("name", .string, .required)
                .field("youtube_id", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}
