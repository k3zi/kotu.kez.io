import Fluent
import Vapor

final class Feedback: Model, Content {

    static let schema = "feedback"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil, value: String) {
        self.id = id
        self.value = value
    }

}

extension Feedback {

    struct Create: Content {
        let value: String
    }

}

extension Feedback {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFeedback" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("value", .date, .required)
                .field("created_at", .date)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateFeedback1" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("value")
                .field("value", .string, .required)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("value")
                .field("value", .date, .required)
                .update()
        }
    }

}

