import Fluent
import Vapor

final class ExternalFile: Model, Content {

    static let schema = "external_files"

    @ID(key: .id)
    var id: UUID?

    @OptionalParent(key: "owner_id")
    var owner: User?

    @OptionalParent(key: "dictionary_id")
    var dictionary: Dictionary?

    @Field(key: "size")
    var size: Int

    @Field(key: "path")
    var path: String

    @OptionalField(key: "alias_path")
    var aliasPath: String?

    @Field(key: "ext")
    var ext: String

    init() { }

    init(id: UUID? = nil, owner: User? = nil, dictionary: Dictionary? = nil, size: Int, path: String, aliasPath: String? = nil, ext: String) {
        self.id = id
        self.$owner.id = try? owner?.requireID()
        self.$dictionary.id = try? dictionary?.requireID()
        self.size = size
        self.aliasPath = aliasPath
        self.path = path
        self.ext = ext
    }

}

extension ExternalFile {

    struct Migration: Fluent.Migration {
        var name: String { "CreateMediaExternalFile" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("owner_id", .uuid, .references("users", "id"))
                .field("size", .int, .required)
                .field("path", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateMediaExternalFile1" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("ext", .string, .required)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("ext")
                .update()
        }
    }

    struct Migration2: Fluent.Migration {
        var name: String { "CreateMediaExternalFile2" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("dictionary_id", .uuid, .references("dictionaries", "id"))
                .field("alias_path", .string)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("dictionary_id")
                .deleteField("alias_path")
                .update()
        }
    }

}

