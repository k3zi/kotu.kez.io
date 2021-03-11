import Fluent
import Vapor

final class DictionaryRemoveJob: Model, Content {

    static let schema = "dictionary_remove_jobs"

    @ID(key: .id)
    var id: UUID?

    @OptionalParent(key: "dictionary_id")
    var dictionary: Dictionary?

    init() { }

    init(id: UUID? = nil, dictionary: Dictionary) {
        self.id = id
        self.$dictionary.id = try! dictionary.requireID()
    }

}

extension DictionaryRemoveJob {

    struct Migration: Fluent.Migration {
        var name: String { "CreateDictionaryRemoveJob" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("dictionary_id", .uuid, .references("dictionaries", "id"))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}
