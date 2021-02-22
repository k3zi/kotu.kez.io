import Fluent
import Vapor

final class YouTubeSubtitle: Model, Content {

    static let schema = "youtube_subtitles"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "youtube_video_id")
    var youtubeVideo: YouTubeVideo

    @Field(key: "text")
    var text: String

    @Field(key: "start_time")
    var startTime: Double

    @Field(key: "end_time")
    var endTime: Double

    init() { }

    init(id: UUID? = nil, youtubeVideo: YouTubeVideo, text: String, startTime: Double, endTime: Double) {
        self.id = id
        self.$youtubeVideo.id = try! youtubeVideo.requireID()
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }

}

extension YouTubeSubtitle {

    struct Migration: Fluent.Migration {
        var name: String { "CreateYouTubeSubtitle" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .id()
                .field("youtube_video_id", .uuid, .required, .references("youtube_videos", "id"))
                .field("youtube_id", .string, .required)
                .field("text", .string, .required)
                .field("start_time", .double, .required)
                .field("end_time", .double, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema).delete()
        }
    }

    struct Migration1: Fluent.Migration {
        var name: String { "CreateYouTubeSubtitleFix" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema(schema)
                .deleteField("youtube_id")
                .update()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.eventLoop.future()
        }
    }

}

