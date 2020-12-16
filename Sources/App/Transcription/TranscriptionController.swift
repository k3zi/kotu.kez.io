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

        project.post(":id", "translation", "create") { (req: Request) -> EventLoopFuture<Translation> in
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

        project.post(":id", "fragment", "create") { (req: Request) -> EventLoopFuture<Fragment> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "ID not provided") }

            try Fragment.Create.validate(content: req)
            let object = try req.content.decode(Fragment.Create.self)
            guard object.startTime <= object.endTime else {
                throw Abort(.badRequest, reason: "Start time can not be greater than end time")
            }

            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$translations)
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID}, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .throwingFlatMap { project in
                    let fragment = Fragment(projectID: try project.requireID(), startTime: object.startTime, endTime: object.endTime)
                    return fragment.save(on: req.db)
                        .throwingFlatMap {
                            guard let baseTranslation = project.translations.first(where: { $0.id == object.baseTranslationID }) else {
                                throw Abort(.unauthorized, reason: "Base translation could not be found")
                            }
                            var subtitles = [Subtitle]()
                            let baseSubtitle = Subtitle(translationID: try baseTranslation.requireID(), fragmentID: try fragment.requireID(), text: object.baseText)
                            subtitles.append(baseSubtitle)
                            
                            if let targetText = object.targetText, targetText.count > 0, let targetTranslationID = object.targetTranslationID {
                                guard let targetTranslation = project.translations.first(where: { $0.id == targetTranslationID }) else {
                                    throw Abort(.unauthorized, reason: "Target translation could not be found")
                                }

                                let targetSubtitle = Subtitle(translationID: try targetTranslation.requireID(), fragmentID: try fragment.requireID(), text: targetText)
                                subtitles.append(targetSubtitle)
                            }
                            return fragment.$subtitles.create(subtitles, on: req.db)
                        }
                        .map { fragment }
                }
        }

        project.post(":id", "subtitle", "create") { (req: Request) -> EventLoopFuture<Subtitle> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "Project ID not provided") }

            try Subtitle.Create.validate(content: req)
            let object = try req.content.decode(Subtitle.Create.self)
            return Project.query(on: req.db)
                .with(\.$owner)
                .with(\.$translations)
                .with(\.$fragments) { $0.with(\.$subtitles) { $0.with(\.$translation) } }
                .filter(\.$id == id)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Project not found"))
                .guard({ $0.owner.id == userID}, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .throwingFlatMap { project in
                    guard let translation = project.translations.first(where: { $0.id == object.translationID }) else {
                        throw Abort(.unauthorized, reason: "Translation could not be found")
                    }

                    guard let fragment = project.fragments.first(where: { $0.id == object.fragmentID }) else {
                        throw Abort(.unauthorized, reason: "Fragment could not be found")
                    }

                    guard !fragment.subtitles.contains(where: { $0.translation.id == translation.id }) else {
                        throw Abort(.unauthorized, reason: "Duplicate subtitle found")
                    }

                    let subtitle = Subtitle(translationID: try translation.requireID(), fragmentID: try fragment.requireID(), text: object.text)
                    return subtitle.save(on: req.db)
                        .map { subtitle }
                }
        }

        project.put(":id", "subtitle", ":subtitleID") { (req: Request) -> EventLoopFuture<Subtitle> in
            let user = try req.auth.require(User.self)
            let userID = try user.requireID()
            guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest, reason: "Project ID not provided") }
            guard let subtitleID = req.parameters.get("subtitleID", as: UUID.self) else { throw Abort(.badRequest, reason: "Subtitle ID not provided") }

            try Subtitle.Update.validate(content: req)
            let object = try req.content.decode(Subtitle.Update.self)
            return Subtitle.query(on: req.db)
                .with(\.$fragment) { $0.with(\.$project) { $0.with(\.$owner) } }
                .filter(\.$id == subtitleID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Subtitle not found"))
                .guard({ $0.fragment.project.owner.id == userID }, else: Abort(.unauthorized, reason: "You are not authorized to view this project"))
                .guard({ $0.fragment.project.id == id }, else: Abort(.unauthorized, reason: "Subtitle does not belong to this project"))
                .flatMap { subtitle in
                    subtitle.text = object.text
                    return subtitle.update(on: req.db)
                        .map { subtitle }
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
