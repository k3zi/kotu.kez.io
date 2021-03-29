import Fluent
import Vapor

final class ReaderSession: Model, Content {

    static let schema = "reader_sessions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    // This should be read-only for items with URLs.
    @Field(key: "annotated_content")
    var annotatedContent: String

    @Field(key: "text_content")
    var textContent: String

    @Field(key: "content")
    var content: String

    @Field(key: "ruby_type")
    var rubyType: String

    @Field(key: "visual_type")
    var visualType: String

    @OptionalField(key: "url")
    var url: String?

    @Field(key: "scroll_phrase_index")
    var scrollPhraseIndex: Int

    @OptionalField(key: "title")
    var title: String?

    @OptionalParent(key: "media_id")
    var media: AnkiDeckVideo?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, owner: User, annotatedContent: String, textContent: String, content: String, rubyType: String, visualType: String, url: String? = nil, title: String? = nil) {
        self.id = id
        self.$owner.id = try! owner.requireID()
        self.annotatedContent = annotatedContent
        self.textContent = textContent
        self.content = content
        self.rubyType = rubyType
        self.visualType = visualType
        self.url = url
        self.scrollPhraseIndex = 0
        self.title = title
    }

}

extension ReaderSession {

    struct Migration: Fluent.Migration {
        var name: String { "CreateReaderSession" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .field("annotated_content", .string, .required)
                .field("text_content", .string, .required)
                .field("content", .string, .required)
                .field("url", .string)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateReaderSessionOptions" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("ruby_type", .string, .required, .sql(.default("none")))
                .field("visual_type", .string, .required, .sql(.default("none")))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("ruby_type")
                .deleteField("visual_type")
                .update()
        }
    }

    struct Migration2: Fluent.Migration {
        var name: String { "CreateReaderSessionScroll" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("scroll_phrase_index", .int, .required, .sql(.default(0)))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("scroll_phrase_index")
                .update()
        }
    }

    struct Migration3: Fluent.Migration {
        var name: String { "CreateReaderSessionTitle" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("title", .string)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("title")
                .update()
        }
    }

    struct Migration4: Fluent.Migration {
        var name: String { "AddReaderSessionUpdateDate" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("updated_at", .datetime)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("updated_at")
                .update()
        }
    }

    struct Migration5: Fluent.Migration {
        var name: String { "AddReaderSessionMedia" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("media_id", .uuid, .references("anki_deck_videos", "id"))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("media_id")
                .update()
        }
    }

}

extension ReaderSession {

    struct Create: Content {
        let annotatedContent: String
        let textContent: String
        let content: String
        let rubyType: String
        let visualType: String
        let url: String?
        let title: String?
    }

    struct Update: Content {
        let annotatedContent: String?
        let textContent: String?
        let content: String?
        let rubyType: String
        let visualType: String
        let url: String?
        let mediaID: UUID?
        let scrollPhraseIndex: Int
    }

}

extension ReaderSession.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("annotatedContent", as: String.self)
        validations.add("textContent", as: String.self)
        validations.add("content", as: String.self)
        validations.add("rubyType", as: String.self)
        validations.add("visualType", as: String.self)
    }

}

extension ReaderSession.Update: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("rubyType", as: String.self)
        validations.add("visualType", as: String.self)
        validations.add("scrollPhraseIndex", as: Int.self)
    }

}

