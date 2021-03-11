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

    @Siblings(through: DictionaryOwner.self, from: \.$dictionary, to: \.$owner)
    var owners: [User]

    @OptionalChild(for: \.$dictionary)
    var insertJob: DictionaryInsertJob?

    @Children(for: \.$dictionary)
    var entries: [Entry]

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

}

final class DictionaryOwner: Model {
    static let schema = "dictionary+user"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "dictionary_id")
    var dictionary: Dictionary

    @Parent(key: "owner_id")
    var owner: User

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

}
