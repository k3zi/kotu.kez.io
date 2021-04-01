import Fluent
import Vapor

final class Deck: Model, Content {

    enum NewOrder: String, Codable {
        case random
        case added
    }

    enum ReviewOrder: String, Codable {
        case random
        case due
    }

    enum ScheduleOrder: String, Codable {
        case mixNewAndReview
        case newAfterReview
        case newBeforeReview
    }

    static let schema = "flashcard_decks"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "name")
    var name: String

    @Field(key: "schedule_order")
    var scheduleOrder: String

    @Field(key: "new_order")
    var newOrder: String

    @Field(key: "review_order")
    var reviewOrder: String

    // The UUID of the individual `Card`s is used.
    @Field(key: "sweet_memo")
    var sm: SweetMemo

    @Field(key: "requested_fi")
    var requestedFI: Double

    @Children(for: \.$deck)
    var cards: [Card]

    init() { }

    init(id: UUID? = nil, ownerID: UUID, name: String, sm: SweetMemo) {
        self.id = id
        self.$owner.id = ownerID
        self.name = name
        self.sm = sm
        self.requestedFI = sm.requestedFI
    }

}

extension Deck {

    struct Response: Content {
        let id: UUID
        let name: String
        let requestedFI: Double
        let scheduleOrder: ScheduleOrder
        let newOrder: NewOrder
        let reviewOrder: ReviewOrder
        let newCardsCount: Int
        let reviewCardsCount: Int
        let nextCardDueDate: Date?
    }

}

extension Deck {

    struct Migration: Fluent.Migration {
        var name: String { "CreateFlashcardDeck" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("owner_id", .uuid, .required, .references("users", "id"))
                .field("name", .string, .required)
                .field("sweet_memo", .json, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "FlashcardDeckOrder" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("schedule_order", .string, .required, .sql(.default("mixNewAndReview")))
                .field("new_order", .string, .required, .sql(.default("added")))
                .field("review_order", .string, .required, .sql(.default("random")))
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("schedule_order")
                .deleteField("new_order")
                .deleteField("review_order")
                .update()
        }
    }

    struct Migration2: Fluent.Migration {
        var name: String { "FlashcardDeckOffsetGrade" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            Deck.query(on: database)
                .all()
                .flatMap { decks in
                    for deck in decks {
                        let sm = deck.sm
                        sm.forgettingIndexGraph.points = sm.forgettingIndexGraph.points.map {
                            SweetMemo.Point(x: $0.x, y: $0.y + 1)
                        }
                        deck.sm = sm
                    }
                    return EventLoopFuture<Void>.andAllSucceed(decks.map { $0.save(on: database) }, on: database.eventLoop)
                }
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            Deck.query(on: database)
                .all()
                .flatMap { decks in
                    for deck in decks {
                        let sm = deck.sm
                        sm.forgettingIndexGraph.points = sm.forgettingIndexGraph.points.map {
                            SweetMemo.Point(x: $0.x, y: $0.y - 1)
                        }
                        deck.sm = sm
                    }
                    return EventLoopFuture<Void>.andAllSucceed(decks.map { $0.save(on: database) }, on: database.eventLoop)
                }
        }
    }

    struct Migration3: Fluent.Migration {
        var name: String { "FlashcardDeckRequestedFI" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .field("requested_fi", .double, .required, .sql(.default(8)))
                .update()
                .flatMap {
                    Deck.query(on: database)
                        .all()
                        .flatMap { decks in
                            for deck in decks {
                                deck.requestedFI = deck.sm.requestedFI
                            }
                            return EventLoopFuture<Void>.andAllSucceed(decks.map { $0.save(on: database) }, on: database.eventLoop)
                        }
                }
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("requested_fi")
                .update()
        }
    }

}

extension Deck {

    struct Create: Content {
        let name: String
    }

    struct Update: Content {
        let name: String
        let requestedFI: Int
        let scheduleOrder: ScheduleOrder
        let reviewOrder: ReviewOrder
        let newOrder: NewOrder
    }

}

extension Deck.Create: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
    }

}

extension Deck.Update: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("requestedFI", as: Int.self)
    }

}
