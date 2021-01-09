import Fluent
import Vapor

final class ListWord: Model, Content {

    static let schema = "list_words"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "value")
    var value: String

    @Field(key: "note")
    var note: String

    @Field(key: "lookups")
    var lookups: Int

    @Field(key: "tags")
    var tags: [String]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

//    @Children(key: "media")
//    var media: [ListMedia]

    init() { }

    init(id: UUID? = nil, owner: User, value: String, note: String, tags: [String]) {
        self.id = id
        self.$owner.id = try! owner.requireID()
        self.value = value
        self.note = note
        self.tags = tags
        self.lookups = 0
    }

}

extension ListWord {

    struct Migration: Fluent.Migration {
        var name: String { "CreateListWord" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("value", .string, .required)
                .field("note", .string, .required)
                .field("tags", .array(of: .string), .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateListWordOwner" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("owner_id")
                .update()
        }
    }

    struct Migration2: Fluent.Migration {
        var name: String { "CreateListWordCreatedAt" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("created_at", .date)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("created_at")
                .update()
        }
    }

    struct Migration3: Fluent.Migration {
        var name: String { "CreateListWordLookups" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("lookups", .int, .required)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("lookups")
                .update()
        }
    }

}

extension ListWord {

    struct Create: Content {
        let value: String
        let note: String?
        let tags: [String]?
    }

    struct Put: Content {
        let value: String
        let note: String
        let tags: [String]
    }

}

extension ListWord.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("value", as: String.self, is: !.empty)
    }

}

extension ListWord.Put: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("value", as: String.self, is: !.empty)
        validations.add("note", as: String.self)
        validations.add("tags", as: [String].self)
    }

}
