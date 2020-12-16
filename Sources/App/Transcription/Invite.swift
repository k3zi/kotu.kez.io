import Fluent
import Vapor

final class Invite: Model, Content {

    static let schema = "transcription_invites"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: Project

    @Parent(key: "invitee_id")
    var invitee: User

    init() { }

    init(id: UUID? = nil, projectID: UUID, inviteeID: UUID) {
        self.id = id
        self.$project.id = projectID
        self.$invitee.id = inviteeID
    }

}

extension Invite {

    struct Migration: Fluent.Migration {
        var name: String { "CreateTranscriptionInvite" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("project_id", .uuid, .required, .references("transcription_projects", "id"))
                .field("invitee_id", .uuid, .required, .references("users", "id"))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}
