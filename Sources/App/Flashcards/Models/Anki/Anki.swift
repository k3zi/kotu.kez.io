import Fluent
import FluentKit
import Vapor

enum Anki {
}

extension Anki {
    final class Card: Fluent.Model, Content {

        static let schema = "cards"

        @ID(custom: "id", generatedBy: .user)
        var id: Int?

        @Field(key: "did")
        var deck: Int

        @Field(key: "nid")
        var note: Int

        @Field(key: "ord")
        var ordinal: Int

        init() { }

    }

    final class Collection: Fluent.Model, Content {

        static let schema = "col"

        @ID(custom: "id", generatedBy: .user)
        var id: Int?

        @Field(key: "models")
        var models: [Int: Anki.Model]

        @Field(key: "decks")
        var decks: [Int: Deck]

        init() { }

    }

    final class Note: Fluent.Model, Content {

        static let schema = "notes"

        @ID(custom: "id", generatedBy: .user)
        var id: Int?

        @Field(key: "mid")
        var modelID: Int

        @Field(key: "tags")
        var tags: String

        @Field(key: "flds")
        var fields: String

        init() { }

    }

    struct Model: Content {
        struct Field: Content {
            let ord: Int
            let name: String
        }
        struct Template: Content {
            let ord: Int
            let name: String
            let qfmt: String
            let afmt: String
        }
        let id: Int
        let name: String
        let css: String
        let flds: [Field]
        let tmpls: [Template]
    }

    struct Deck: Content {
        let id: Int
        let name: String
        let desc: String
    }

}
