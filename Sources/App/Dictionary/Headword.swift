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

    init() { }

    init(id: UUID? = nil, dictionary: Dictionary, text: String, headline: String, shortHeadline: String, entryIndex: Int, subentryIndex: Int) {
        self.id = id
        self.dictionary = dictionary
        self.text = text
        self.headline = headline
        self.shortHeadline = shortHeadline
        self.entryIndex = entryIndex
        self.subentryIndex = subentryIndex
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

}
