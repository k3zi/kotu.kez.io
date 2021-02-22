import Fluent
import Vapor

final class YouTubeVideo: Model, Content {

    static let schema = "youtube_videos"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "youtube_id")
    var youtubeID: String

    @Field(key: "title")
    var title: String

    @Field(key: "thumbnail_url")
    var thumbnailURL: String

    @Children(for: \.$youtubeVideo)
    var subtitles: [YouTubeSubtitle]

    init() { }

    init(id: UUID? = nil, youtubeID: String, title: String, thumbnailURL: String) {
        self.id = id
        self.youtubeID = youtubeID
        self.title = title
        self.thumbnailURL = thumbnailURL
    }

}

extension YouTubeVideo {

    struct Migration: Fluent.Migration {
        var name: String { "CreateYouTubeVideo" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("youtube_id", .string, .required)
                .field("title", .string, .required)
                .field("thumbnail_url", .string, .required)
                .unique(on: "youtube_id")
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

}

