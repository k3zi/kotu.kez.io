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

    api.get("me") { req -> User in
        return try req.auth.require(User.self)
    }

    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get(.catchall) { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

}
