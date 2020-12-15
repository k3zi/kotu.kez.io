import Fluent
import Vapor

class TranscriptionController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let transcription = routes.grouped("transcription")
            .grouped(User.guardMiddleware())

        let projects = transcription.grouped("projects")

        projects.get { req -> EventLoopFuture<[Project]> in
            let user = try req.auth.require(User.self)
            return user.$projects
                .query(on: req.db)
                .with(\.$translations) { translation in
                    translation.with(\.$language)
                }
                .all()
        }

        let project = transcription.grouped("project")
        project.post("create") { req -> EventLoopFuture<Project> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()

            try Project.Create.validate(content: req)
            let object = try req.content.decode(Project.Create.self)
            return Language.find(object.languageID, on: req.db)
                .unwrap(orError: Abort(.badRequest, reason: "Language not found"))
                .throwingFlatMap { language in
                    guard let languageID = language.id else { throw Abort(.internalServerError, reason: "Could not access language ID") }
                    let project = Project(ownerID: userID, name: object.name, youtubeID: object.youtubeID)

                    return project
                        .save(on: req.db)
                        .throwingFlatMap {
                            guard let projectID = project.id else { throw Abort(.internalServerError, reason: "Could not access project ID") }
                            let translation = Translation(projectID: projectID, languageID: languageID, isOriginal: true)
                            return translation.save(on: req.db)
                        }
                        .map { project }
                }
        }

        project.get(":id") { (req: Request) -> EventLoopFuture<Project> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            // In the future do a join for shared projects.
            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$translations) { translation in
                    translation.with(\.$language)
                }
                .with(\.$fragments) { fragments in
                    fragments.with(\.$subtitles) { subtitle in
                        subtitle.with(\.$translation)
                    }
                }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID}, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
        }

        project.post(":id", "translations", "create") { (req: Request) -> EventLoopFuture<Translation> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try Translation.Create.validate(content: req)
            let object = try req.content.decode(Translation.Create.self)

            return Project.query(on: req.db)
                .with(\.$owner)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID}, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .flatMap { project in
                    Language.find(object.languageID, on: req.db)
                        .unwrap(orError: Abort(.badRequest, reason: "Language not found"))
                        .throwingFlatMap { language in
                            let projectID = try project.requireID()
                            let languageID = try language.requireID()
                            let translation = Translation(projectID: projectID, languageID: languageID, isOriginal: false)
                            return translation.save(on: req.db)
                                .map { translation }
                        }
                }
        }

        project.delete(":id") { (req: Request) -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            return user.$projects
                .query(on: req.db)
                .filter(\.$id == id)
                .with(\.$translations)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .flatMap { project in
                    project.translations.delete(on: req.db)
                        .flatMap { project.delete(on: req.db) }
                }
                .map { "Project deleted." }
        }
    }

}
