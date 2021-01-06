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

    @Field(key: "share_all_projects")
    var shareAllProjects: Bool

    init() { }

    init(id: UUID? = nil, projectID: UUID, inviteeID: UUID, shareAllProjects: Bool) {
        self.id = id
        self.$project.id = projectID
        self.$invitee.id = inviteeID
        self.shareAllProjects = shareAllProjects
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

    struct Migration1: Fluent.Migration {
        var name: String { "TranscriptionInviteShareAll" }

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

extension Invite {

    struct Create: Content {
        let shareAllProjects: Bool
    }

}

extension Invite.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("shareAllProjects", as: Bool.self)
    }

}
