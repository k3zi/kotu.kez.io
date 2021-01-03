import Fluent
import Vapor

final class User: Model, Content {

    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "permissions")
    var permissions: [String]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @OptionalField(key: "password_reset_date")
    var passwordResetDate: Date?

    @OptionalField(key: "password_reset_key")
    var passwordResetKey: String?

    // MARK: Transcription

    @Children(for: \.$owner)
    var projects: [Project]

    @Children(for: \.$invitee)
    var invites: [Invite]

    @Children(for: \.$sharedUser)
    var shares: [Share]

    // MARK: Flashcards

    @Children(for: \.$owner)
    var decks: [Deck]

    @Children(for: \.$owner)
    var noteTypes: [NoteType]

    // MARK: Media

    @Children(for: \.$owner)
    var files: [File]

    init() { }

    init(id: UUID? = nil, username: String, passwordHash: String) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
    }

    func beforeEncode() throws {
        self.passwordHash = ""
    }

}

extension User {

    struct Migration: Fluent.Migration {
        var name: String { "CreateUser" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .id()
                .field("username", .string, .required, .sql(.unique))
                .field("password_hash", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users").delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "AddUserCreationDate" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .field("created_at", .date)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("created_at")
                .update()
        }
    }

    struct Migration2: Fluent.Migration {
        var name: String { "AddUserPermissions" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .field("permissions", .array)
                .field("password_reset_date", .date)
                .field("password_reset_key", .string)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("password_reset_date")
                .deleteField("password_reset_key")
                .update()
        }
    }

    struct Migration3: Fluent.Migration {
        var name: String { "AddUserPermissions3" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("permissions")
                .field("permissions", .array(of: .string))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("permissions")
                .field("permissions", .array)
                .update()
        }
    }

    struct Migration4: Fluent.Migration {
        var name: String { "AddUserPermissions4" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.enum("permissions")
                .case("admin")
                .create()
                .flatMap { _ in
                    database.schema("users")
                        .deleteField("permissions")
                        .field("permissions", .sql(raw: "text[]"))
                        .update()
                }
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("permissions")
                .field("permissions", .array(of: .string))
                .update()
        }
    }

    struct Migration5: Fluent.Migration {
        var name: String { "AddUserPermissions5" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("permissions")
                .field("permissions", .array(of: .string))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.eventLoop.future()
        }
    }

    struct Migration6: Fluent.Migration {
        var name: String { "AddUserPermissions6" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            User.query(on: database)
                .set(\.$permissions, to: [])
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.eventLoop.future()
        }
    }

    struct Migration7: Fluent.Migration {
        var name: String { "AddUserPasswordReset7" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("password_reset_date")
                .field("password_reset_date", .datetime)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("password_reset_date")
                .field("password_reset_date", .date)
                .update()
        }
    }




}

extension User {

    struct Create: Content {
        let username: String
        let password: String
        let confirmPassword: String
    }

}

extension User.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: !.empty)
        validations.add("username", as: String.self, is: .count(4...) && .alphanumeric)

        validations.add("password", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(6...))
    }

}

extension User: SessionAuthenticatable {

    var sessionID: UUID {
        self.id ?? .init()
    }

}

extension User: ModelCredentialsAuthenticatable {

    static let usernameKey = \User.$username
    static let passwordHashKey = \User.$passwordHash

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }

}

extension User {

    static var guest: User {
        User(id: .init(), username: "Guest", passwordHash: "")
    }

}
