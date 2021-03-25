import Fluent
import Vapor

final class DictionaryRemoveJob: Model, Content {

    static let schema = "dictionary_remove_jobs"

    @ID(key: .id)
    var id: UUID?

    @OptionalParent(key: "dictionary_id")
    var dictionary: Dictionary?

    @Field(key: "has_started")
    var hasStarted: Bool

    init() { }

    init(id: UUID? = nil, dictionary: Dictionary) {
        self.id = id
        self.$dictionary.id = try! dictionary.requireID()
        self.hasStarted = false
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

    struct Migration1: Fluent.Migration {
        var name: String { "CreateDictionaryRemoveJobHasStarted" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("has_started", .bool, .required, .sql(.default(false)))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("has_started")
                .update()
        }
    }

}
