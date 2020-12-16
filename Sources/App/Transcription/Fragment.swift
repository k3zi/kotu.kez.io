import Fluent
import Vapor

final class Fragment: Model, Content {

    static let schema = "transcription_fragments"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: Project

    @Field(key: "start_time")
    var startTime: Double

    @Field(key: "end_time")
    var endTime: Double

    @Children(for: \.$fragment)
    var subtitles: [Subtitle]

    init() { }

    init(id: UUID? = nil, projectID: UUID, startTime: Double, endTime: Double) {
        self.id = id
        self.$project.id = projectID
        self.startTime = startTime
        self.endTime = endTime
    }

}

extension Fragment {

    struct Migration: Fluent.Migration {
        var name: String { "CreateTranscriptionFragment" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("project_id", .uuid, .required, .references("transcription_projects", "id"))
                .field("start_time", .double, .required)
                .field("end_time", .double, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}

extension Fragment {

    struct Create: Content {
        let baseText: String
        let baseTranslationID: UUID
        let targetText: String?
        let targetTranslationID: UUID?
        let startTime: Double
        let endTime: Double
    }

}

extension Fragment.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("baseText", as: String.self)
        validations.add("baseTranslationID", as: UUID.self)
        validations.add("targetText", as: String?.self, required: false)
        validations.add("targetTranslationID", as: UUID?.self, required: false)
        validations.add("startTime", as: Double.self)
        validations.add("endTime", as: Double.self)
    }

}
