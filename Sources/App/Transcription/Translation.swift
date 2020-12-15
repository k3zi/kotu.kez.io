import Fluent
import Vapor

final class Translation: Model, Content {

    static let schema = "transcription_translations"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: Project

    @Parent(key: "language_id")
    var language: Language

    @Field(key: "is_original")
    var isOriginal: Bool

    init() { }

    init(id: UUID? = nil, projectID: UUID, languageID: UUID, isOriginal: Bool) {
        self.id = id
        self.$project.id = projectID
        self.$language.id = languageID
        self.isOriginal = isOriginal
    }

}

extension Translation {

    struct Migration: Fluent.Migration {
        var name: String { "CreateTranscriptionTranslation" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("project_id", .uuid, .required, .references("transcription_projects", "id"))
                .field("language_id", .uuid, .required, .references("languages", "id"))
                .field("is_original", .bool, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}

extension Translation {

    struct Create: Content {
        let languageID: UUID
    }

}

extension Translation.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("languageID", as: UUID.self)
    }

}
