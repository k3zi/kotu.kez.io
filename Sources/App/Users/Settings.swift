import Vapor

struct Settings: Content {

    enum CodingKeys: String, CodingKey {
        case reader
    }

    struct Reader: Content {
        enum CodingKeys: String, CodingKey {
            case showCreateNoteForm
        }

        var showCreateNoteForm: Bool = true

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            showCreateNoteForm = (try? container.decodeIfPresent(Bool.self, forKey: .showCreateNoteForm)) ?? true
        }
    }

    var reader = Reader()

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reader = (try? container.decodeIfPresent(Reader.self, forKey: .reader)) ?? Reader()
    }

}
