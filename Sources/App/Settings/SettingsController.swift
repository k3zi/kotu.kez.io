import Fluent
import Vapor

class SettingsController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let settings = routes.grouped("settings")

        settings.get("languages") { req -> EventLoopFuture<[Language]> in
            Language.query(on: req.db).all().map { languages in
                languages.sorted { $0.name < $1.name }
            }
        }
    }

}
