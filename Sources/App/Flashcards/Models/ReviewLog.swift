import Fluent
import Vapor

final class ReviewLog: Model, Content {

    static let schema = "flashcard_review_logs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "card_id")
    var card: Card

    @Field(key: "grade")
    var grade: Double

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "group_date", on: .create)
    var groupDate: Date?

    init() { }

    init(id: UUID? = nil, card: Card, grade: Double) throws{
        self.id = id
        self.$card.id = try card.requireID()
        self.grade = grade
    }

}

extension ReviewLog {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFlashcardReviewLog" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("card_id", .uuid, .required, .references("flashcard_cards", "id"))
                .field("grade", .double, .required)
                .field("created_at", .datetime)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateFlashcardReviewLogGroupDate" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("group_date", .date)
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("group_date")
                .update()
        }
    }

}
