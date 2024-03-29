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

    @Field(key: "ignore_words")
    var knownWords: [String]

    @OptionalField(key: "words")
    var words: [Word]?

    @OptionalField(key: "plex_auth")
    var plexAuth: SignInResponse?

    @OptionalField(key: "settings")
    var settings: Settings?

    @Children(for: \.$owner)
    var tokens: [UserToken]

    // MARK: Blog

    @Children(for: \.$owner)
    var blogPosts: [BlogPost]

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

    @Children(for: \.$owner)
    var readerSessions: [ReaderSession]

    // MARK: Lists

    @Children(for: \.$owner)
    var listWords: [ListWord]

    // MARK: Dictionaries
    @Siblings(through: DictionaryOwner.self, from: \.$owner, to: \.$dictionary)
    public var dictionaries: [Dictionary]

    init() { }

    init(id: UUID? = nil, username: String, passwordHash: String) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
        self.permissions = []
        self.knownWords = []
    }

    func beforeEncode() throws {
        self.passwordHash = ""
        self.settings = self.settings ?? Settings()
    }

    func asResponse() throws -> Response {
        Response(username: username)
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

    struct Migration8: Fluent.Migration {
        var name: String { "AddUserIgnoreWords" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .field("ignore_words", .array(of: .string))
                .update()
                .flatMap {
                    User.query(on: database)
                        .set(\.$knownWords, to: [])
                        .update()
                }
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("ignore_words")
                .update()
        }
    }

    struct Migration9: Fluent.Migration {
        var name: String { "AddUserPlexAuth" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .field("plex_auth", .json)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("plex_auth")
                .update()
        }
    }

    struct Migration10: Fluent.Migration {
        var name: String { "AddUserSettings" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .field("settings", .json)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("settings")
                .update()
        }
    }

    struct Migration11: Fluent.Migration {
        var name: String { "AddUserWords" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .field("words", .json)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("words")
                .update()
        }
    }

    struct Migration12: Fluent.Migration {
        var name: String { "AddUserWords1" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("words")
                .field("words", .array(of: .json))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .deleteField("words")
                .field("words", .json)
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

    struct Response: Content {
        let username: String
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

    func generateToken() throws -> UserToken {
        try .init(
            value: [UInt8].random(count: 32).base64.filter { $0 != "=" },
            userID: self.requireID()
        )
    }

    static var guest: User {
        User(id: .init(), username: "Guest", passwordHash: "")
    }

}
