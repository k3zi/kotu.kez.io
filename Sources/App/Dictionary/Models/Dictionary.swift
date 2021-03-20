import Fluent
import Vapor

final class Dictionary: Model, Content {

    static let schema = "dictionaries"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "directoryName")
    var directoryName: String

    @Field(key: "sha")
    var sha: String

    @Field(key: "type")
    var type: String

    @Field(key: "css")
    var css: String

    @Field(key: "dark_css")
    var darkCSS: String

    @OptionalField(key: "icon")
    var icon: Data?

    @Siblings(through: DictionaryOwner.self, from: \.$dictionary, to: \.$owner)
    var owners: [User]

    @OptionalChild(for: \.$dictionary)
    var insertJob: DictionaryInsertJob?

    @Children(for: \.$dictionary)
    var entries: [Entry]

    @Children(for: \.$dictionary)
    var headwords: [Headword]

    init() { }

    init(id: UUID? = nil, name: String, sha: String) {
        self.id = id
        self.name = name
        self.directoryName = ""
        self.sha = sha
        self.type = "unknown"
    }

}

extension Dictionary {

    struct Update: Content {
        let id: UUID
        let order: Int
    }

    struct Simple: Content {
        let id: UUID?
        let order: Int
        let name: String
        let insertJob: DictionaryInsertJob?

        init(dictionary: Dictionary, user: User) {
            id = dictionary.id
            order = dictionary.$owners.pivots.filter { $0.$owner.id == user.id }.first?.order ?? 0
            name = dictionary.name
            insertJob = dictionary.insertJob
        }
    }

}

extension Dictionary.Update: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("id", as: UUID.self)
        validations.add("order", as: Int.self)
    }

}

extension Dictionary {

    struct Migration: Fluent.Migration {
        var name: String { "CreateDictionary" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("name", .string, .required)
                .field("directoryName", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateDictionarySHA" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("sha", .string, .required, .sql(.default("")))
                .field("type", .string, .required, .sql(.default("")))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("sha")
                .deleteField("type")
                .update()
        }
    }

    struct Migration2: Fluent.Migration {
        var name: String { "CreateDictionaryCSS" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("css", .string, .required, .sql(.default("")))
                .field("dark_css", .string, .required, .sql(.default("")))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("css")
                .deleteField("type")
                .update()
        }
    }

    struct Migration3: Fluent.Migration {
        var name: String { "CreateDictionaryIcon" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("icon", .data)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("icon")
                .update()
        }
    }

}

final class DictionaryOwner: Model {
    static let schema = "dictionary+user"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "dictionary_id")
    var dictionary: Dictionary

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "order")
    var order: Int

    init() { }

    init(id: UUID? = nil, dictionary: Dictionary, owner: User) throws {
        self.id = id
        self.$dictionary.id = try dictionary.requireID()
        self.$owner.id = try owner.requireID()
    }
}

extension DictionaryOwner {

    struct Migration: Fluent.Migration {
        var name: String { "CreateDictionaryOwner" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("dictionary_id", .uuid, .required, .references("dictionaries", "id"))
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .unique(on: "dictionary_id", "owner_id")
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateDictionaryOwnerOrder" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("order", .int, .required, .sql(.default(0)))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("order")
                .update()
        }
    }

}
