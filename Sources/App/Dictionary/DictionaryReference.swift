import Fluent
import Vapor

final class DictionaryReference: Model, Content {

    static let schema = "dictionary_references"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "dictionary_id")
    var dictionary: Dictionary

    @Field(key: "key")
    var key: String

    @OptionalField(key: "entry_index")
    var entryIndex: Int?

    @OptionalField(key: "file_path")
    var filePath: String?

    init() { }

    init(id: UUID? = nil, dictionary: Dictionary, key: String, entryIndex: Int?, filePath: String?) {
        self.id = id
        self.$dictionary.id = try! dictionary.requireID()
        self.key = key
        self.entryIndex = entryIndex
        self.filePath = filePath
    }

}

extension DictionaryReference {

    struct Migration: Fluent.Migration {
        var name: String { "CreateDictionaryReference" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("dictionary_id", .uuid, .references("dictionaries", "id"))
                .field("key", .string, .required)
                .field("entry_index", .int)
                .field("file_path", .string)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}
