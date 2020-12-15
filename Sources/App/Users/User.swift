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

    // Creates a new, empty Planet.
    init() { }

    // Creates a new Planet with all properties set.
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
