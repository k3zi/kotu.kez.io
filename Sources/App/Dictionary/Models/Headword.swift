import Fluent
import Vapor

final class Headword: Model, Content {

    static let schema = "dictionary_headwords"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "text")
    var text: String

    @Field(key: "headline")
    var headline: String

    @Field(key: "short_headline")
    var shortHeadline: String

    @Field(key: "entry_index")
    var entryIndex: Int

    @Field(key: "subentry_index")
    var subentryIndex: Int

    @Parent(key: "dictionary_id")
    var dictionary: Dictionary

    @OptionalParent(key: "entry_id")
    var entry: Entry?

    init() { }

    init(id: UUID? = nil, dictionary: Dictionary, text: String, headline: String, shortHeadline: String, entryIndex: Int, subentryIndex: Int, entry: Entry? = nil) {
        self.id = id
        self.$dictionary.id = try! dictionary.requireID()
        self.text = text
        self.headline = headline
        self.shortHeadline = shortHeadline
        self.entryIndex = entryIndex
        self.subentryIndex = subentryIndex
        if let entry = entry {
            self.$entry.id = try! entry.requireID()
        }
    }

}

extension Headword {

    struct Simple: Content {
        struct Dictionary: Content {
            let id: UUID
        }

        struct Entry: Content {
            let id: UUID
        }

        let dictionary: Dictionary
        let entry: Entry?

        let headline: String
        let shortHeadline: String
        let entryIndex: Int
        let subentryIndex: Int

        init(headword: Headword) {
            dictionary = .init(id: headword.$dictionary.id)
            entry = headword.$entry.id.flatMap { .init(id: $0) }

            headline = headword.headline
            shortHeadline = headword.shortHeadline
            entryIndex = headword.entryIndex
            subentryIndex = headword.subentryIndex
        }
    }

}

extension Headword {

    struct Migration: Fluent.Migration {
        var name: String { "CreateDictionaryHeadword" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("text", .string, .required)
                .field("headline", .string, .required)
                .field("short_headline", .string, .required)
                .field("entry_index", .int, .required)
                .field("subentry_index", .int, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "DictionaryHeadwordDictionary" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("dictionary_id", .uuid, .references("dictionaries", "id"))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("dictionary_id")
                .update()
        }
    }

    struct Migration2: Fluent.Migration {
        var name: String { "DictionaryHeadwordEntry" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("entry_id", .uuid, .references("dictionary_entries", "id"))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("entry_id")
                .update()
        }
    }

}
