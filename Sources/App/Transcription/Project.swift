import Fluent
import Vapor

final class Project: Model, Content {

    static let schema = "transcription_projects"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "name")
    var name: String

    @Field(key: "youtube_id")
    var youtubeID: String

    @Children(for: \.$project)
    var translations: [Translation]

    @Children(for: \.$project)
    var fragments: [Fragment]

    @Children(for: \.$project)
    var shares: [Share]

    @Children(for: \.$project)
    var invites: [Invite]

    init() { }

    init(id: UUID? = nil, ownerID: UUID, name: String, youtubeID: String) {
        self.id = id
        self.$owner.id = ownerID
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

    struct Migration1: Fluent.Migration {
        var name: String { "TranscriptionProjectAddOwner" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("owner_id")
                .update()
        }
    }

}

extension Project {

    struct Create: Content {
        let name: String
        let youtubeID: String
        let languageID: UUID
    }

}

extension Project.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("youtubeID", as: String.self, is: !.empty)
        validations.add("languageID", as: UUID.self)
    }

}

extension Project {

    struct ShareHash: Content {
        let readOnly: String
        let edit: String
    }

}
