import Fluent
import Vapor

final class Share: Model, Content {

    static let schema = "transcription_shares"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: Project

    @Parent(key: "shared_id")
    var sharedUser: User

    init() { }

    init(id: UUID? = nil, projectID: UUID, sharedUserID: UUID) {
        self.id = id
        self.$project.id = projectID
        self.$sharedUser.id = sharedUserID
    }

}

extension Share {

    struct Migration: Fluent.Migration {
        var name: String { "CreateTranscriptionShare" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("project_id", .uuid, .required, .references("transcription_projects", "id"))
                .field("shared_id", .uuid, .required, .references("users", "id"))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}
