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

    init() { }

    init(id: UUID? = nil, name: String, directoryName: String) {
        self.id = id
        self.name = name
        self.directoryName = directoryName
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

}
