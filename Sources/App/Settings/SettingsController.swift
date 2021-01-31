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

        let apiGuardedSettings = settings.grouped(GuardPermissionMiddleware(require: .api))

        apiGuardedSettings.get("token") { req -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            return user.$tokens.query(on: req.db)
                .first()
                .throwingFlatMap {
                    if let token = $0 {
                        return req.eventLoop.future(token.value)
                    }

                    let token = try user.generateToken()
                    return token.save(on: req.db).map {
                        token.value
                    }
                }
        }

        apiGuardedSettings.post("regenerateToken") { req -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            return user.$tokens.query(on: req.db)
                .delete()
                .throwingFlatMap { _ -> EventLoopFuture<String> in
                let token = try user.generateToken()
                return token.save(on: req.db).map {
                    token.value
                }
            }
        }
    }

}
