import Fluent
import Vapor

class BlogController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let blog = routes.grouped("blog")
            .grouped(User.guardMiddleware())

        let guardedBlog = blog
            .grouped(GuardPermissionMiddleware(require: .blog))

        blog.get(":postID") { (req: Request) -> EventLoopFuture<BlogPost.Response> in
            let postID = try req.parameters.require("postID", as: UUID.self)

            return BlogPost.query(on: req.db)
                .with(\.$owner)
                .filter(\.$id == postID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Blog post not found"))
                .flatMapThrowing { try $0.asResponse() }
        }

        blog.get() { req -> EventLoopFuture<Page<BlogPost.Response>> in
            let user = try req.auth.require(User.self)
            var query = BlogPost
                .query(on: req.db)
                .with(\.$owner)
            if !user.permissions.contains(Permission.blog.rawValue) {
                query = query.filter(\.$isDraft == false)
            }

            return query
                .sort(\.$createdAt, .descending)
                .paginate(for: req)
                .flatMapThrowing { try $0.map { try $0.asResponse() } }
        }

        guardedBlog.post() { req -> EventLoopFuture<BlogPost> in
            let user = try req.auth.require(User.self)

            try BlogPost.Create.validate(content: req)
            let object = try req.content.decode(BlogPost.Create.self)
            let post = BlogPost(owner: user, title: object.title, content: object.content ?? "", isDraft: true, tags: object.tags ?? [])
            return post.save(on: req.db).map { post }
        }

        guardedBlog.delete(":postID") { (req: Request) -> EventLoopFuture<String> in
            let user = try req.auth.require(User.self)
            let postID = try req.parameters.require("postID", as: UUID.self)
            return user.$blogPosts
                .query(on: req.db)
                .with(\.$owner)
                .filter(\.$id == postID)
                .first()
                .unwrap(orError: Abort(.badRequest, reason: "Blog post not found"))
                .flatMap {
                    $0.delete(on: req.db)
                }
                .map { "Deleted." }
        }

        guardedBlog.put(":postID") { (req: Request) -> EventLoopFuture<BlogPost> in
            let postID = try req.parameters.require("postID", as: UUID.self)

            try BlogPost.Update.validate(content: req)
            let object = try req.content.decode(BlogPost.Update.self)
            return BlogPost.find(postID, on: req.db)
                .unwrap(orError: Abort(.badRequest, reason: "Blog post not found"))
                .flatMap { blogPost in
                    blogPost.title = object.title
                    blogPost.content = object.content
                    blogPost.tags = object.tags
                    blogPost.isDraft = object.isDraft
                    return blogPost.update(on: req.db)
                        .map { blogPost }
                }
        }

    }

}
