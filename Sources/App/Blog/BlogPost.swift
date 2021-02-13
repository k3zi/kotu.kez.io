import Fluent
import Vapor

final class BlogPost: Model, Content {

    static let schema = "blog_posts"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "title")
    var title: String

    @Field(key: "content")
    var content: String

    @Field(key: "is_draft")
    var isDraft: Bool

    @Field(key: "tags")
    var tags: [String]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil, owner: User, title: String, content: String, isDraft: Bool, tags: [String]) {
        self.id = id
        self.$owner.id = try! owner.requireID()
        self.title = title
        self.content = content
        self.isDraft = isDraft
        self.tags = tags
    }

    func beforeEncode() throws {
        if self.$owner.value != nil {
            try self.owner.beforeEncode()
            self.owner.settings = Settings()
        }
    }

    func asResponse() throws -> Response {
        Response(id: try self.requireID(), owner: try owner.asResponse(), title: title, content: content, isDraft: isDraft, tags: tags, createdAt: createdAt)
    }

}

extension BlogPost {

    struct Migration: Fluent.Migration {
        var name: String { "CreateBlogPost" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .field("title", .string, .required)
                .field("content", .string, .required)
                .field("tags", .array(of: .string), .required)
                .field("created_at", .date)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateBlogPostDraft" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("is_draft", .bool, .required, .sql(.default(true)))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("is_draft")
                .update()
        }
    }

}

extension BlogPost {

    struct Create: Content {
        let title: String
        let content: String?
        let tags: [String]?
    }

    struct Update: Content {
        let title: String
        let content: String
        let isDraft: Bool
        let tags: [String]
    }

    struct Response: Content {
        let id: UUID
        let owner: User.Response
        let title: String
        let content: String
        let isDraft: Bool
        let tags: [String]
        let createdAt: Date?
    }

}

extension BlogPost.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: !.empty)
    }

}

extension BlogPost.Update: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: !.empty)
        validations.add("content", as: String.self, is: !.empty)
        validations.add("isDraft", as: Bool.self)
        validations.add("tags", as: [String].self)
    }

}

