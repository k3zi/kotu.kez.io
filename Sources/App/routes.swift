import Fluent
import Vapor

func routes(_ app: Application) throws {

    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

}
