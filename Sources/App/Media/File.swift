import Fluent
import Vapor

final class File: Model, Content {

    static let schema = "media_files"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "size")
    var size: Int

    @Field(key: "data")
    var data: Data

    init() { }

    init(id: UUID? = nil, owner: User, size: Int, data: Data) {
        self.id = id
        self.$owner.id = try! owner.requireID()
        self.size = size
        self.data = data
    }

    func beforeEncode() throws {
        self.$data.value = nil
    }

}

extension File {

    struct Migration: Fluent.Migration {
        var name: String { "CreateMediaFile" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .field("size", .int, .required)
                .field("data", .data, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}

