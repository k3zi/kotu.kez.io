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

    @Field(key: "share_all_projects")
    var shareAllProjects: Bool

    init() { }

    init(id: UUID? = nil, projectID: UUID, sharedUserID: UUID, shareAllProjects: Bool) {
        self.id = id
        self.$project.id = projectID
        self.$sharedUser.id = sharedUserID
        self.shareAllProjects = shareAllProjects
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

    struct Migration2: Fluent.Migration {
        var name: String { "TranscriptionShareAll" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("share_all_projects", .bool, .required, .sql(.default(false)))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("share_all_projects")
                .update()
        }
    }

}
