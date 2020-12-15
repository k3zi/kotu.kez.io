import Fluent
import Vapor

final class Language: Model, Content {

    static let schema = "languages"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "code")
    var code: String

    init() { }

    init(id: UUID? = nil, name: String, code: String) {
        self.id = id
        self.name = name
        self.code = code
    }

}

extension Language {

    struct Migration: Fluent.Migration {
        var name: String { "CreateLanguage" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("languages")
                .id()
                .field("name", .string, .required)
                .field("code", .string, .required)
                .unique(on: "code")
                .create()
                .flatMap {
                    let languageList = Locale.isoLanguageCodes
                        .map { (Locale.current.localizedString(forLanguageCode: $0), $0) }
                        .filter { $0.0 != nil && $0.1 != "mul" }
                        .map { ($0!, $1) }
                        .map { Language(name: $0, code: $1) }

                    return languageList.create(on: database)
                }
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("languages").delete()
        }
    }

}
