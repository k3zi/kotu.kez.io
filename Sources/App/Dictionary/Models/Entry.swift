import Fluent
import Vapor

final class Entry: Model, Content {

    static let schema = "dictionary_entries"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "dictionary_id")
    var dictionary: Dictionary

    @Field(key: "content")
    var content: String

    @Field(key: "index")
    var index: Int

    init() { }

    init(id: UUID? = nil, dictionary: Dictionary, content: String, index: Int) {
        self.id = id
        self.$dictionary.id = try! dictionary.requireID()
        self.content = content
        self.index = index
    }

}

extension Entry {

    struct Migration: Fluent.Migration {
        var name: String { "CreateDictionaryEntry" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("content", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateDictionaryEntryIndex" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("dictionary_id", .uuid, .required, .references("dictionaries", "id"))
                .field("index", .int, .required)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("dictionary_id")
                .deleteField("index")
                .update()
        }
    }

}
