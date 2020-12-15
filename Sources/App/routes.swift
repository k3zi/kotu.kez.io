import Fluent
import Vapor

func routes(_ app: Application) throws {

    let api = app.grouped("api")
    try api.register(collection: AuthController())
    try api.register(collection: SettingsController())

    api.get("me") { req -> User in
        return try req.auth.require(User.self)
    }

    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get(.anything) { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

}
