import Fluent
import Vapor

func routes(_ app: Application) throws {

    let api = app.grouped("api")
    try api.register(collection: AuthController())

    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get(.anything) { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

}
