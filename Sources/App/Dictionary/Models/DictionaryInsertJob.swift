import Fluent
import Vapor

final class DictionaryInsertJob: Model, Content {

    static let schema = "dictionary_insert_jobs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "dictionary_id")
    var dictionary: Dictionary

    @Field(key: "temp_directory")
    var tempDirectory: String

    @Field(key: "filename")
    var filename: String

    // Ex: mkd, yomichan, etc...
    @Field(key: "type")
    var type: String

    @Field(key: "current_entry_index")
    var currentEntryIndex: Int

    @Field(key: "current_headword_index")
    var currentHeadwordIndex: Int

    @Field(key: "progress")
    var progress: Float

    @Field(key: "is_complete")
    var isComplete: Bool

    @OptionalField(key: "error_message")
    var errorMessage: String?

    init() { }

    init(id: UUID? = nil, dictionary: Dictionary, tempDirectory: String, filename: String, type: String, currentEntryIndex: Int, currentHeadwordIndex: Int) {
        self.id = id
        self.$dictionary.id = try! dictionary.requireID()
        self.tempDirectory = tempDirectory
        self.filename = filename
        self.type = type
        self.currentEntryIndex = currentEntryIndex
        self.currentHeadwordIndex = currentHeadwordIndex
        self.progress = 0
        self.isComplete = false
    }

}

extension DictionaryInsertJob {

    struct Migration: Fluent.Migration {
        var name: String { "CreateDictionaryInsertJob" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("dictionary_id", .uuid, .references("dictionaries", "id"))
                .field("temp_directory", .string, .required)
                .field("filename", .string, .required)
                .field("type", .string, .required)
                .field("current_entry_index", .int, .required)
                .field("current_headword_index", .int, .required)
                .field("progress", .float, .required)
                .field("is_complete", .bool, .required, .sql(.default(false)))
                .field("error_message", .string)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}
