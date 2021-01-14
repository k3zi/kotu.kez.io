import Fluent
import Vapor

func routes(_ app: Application) throws {

    let api = app.grouped("api")
    try api.register(collection: AuthController())
    try api.register(collection: SettingsController())
    try api.register(collection: TranscriptionController())
    try api.register(collection: DictionaryController())
    try api.register(collection: FlashcardController())
    try api.register(collection: MediaController())
    try api.register(collection: TestsController())
    try api.register(collection: AdminController())
    try api.register(collection: ListsController())

    api.get("me") { req -> User in
        return try req.auth.require(User.self)
    }

    api.grouped(User.guardMiddleware())
        .get("proxy") { (req: Request) -> EventLoopFuture<String> in
            let urlString = try req.query.get(String.self, at: "url")
            guard let _ = URL(string: urlString) else {
                throw Abort(.badRequest)
            }
            return req.client.get(.init(string: urlString), headers: .init([
                ("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36")
            ]))
                .map { response in
                    let data = Data(buffer: response.body ?? .init())
                    return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) ?? String(data: data, encoding: .japaneseEUC) ?? ""
                }
        }

    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get(.catchall) { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

}
