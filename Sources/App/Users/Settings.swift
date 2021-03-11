import Vapor

struct Settings: Content {

    enum CodingKeys: String, CodingKey {
        case anki
        case reader
        case ui
    }

    struct Anki: Content {
        enum CodingKeys: String, CodingKey {
            case showFieldPreview
            case lastUsedDeckID
            case lastUsedNoteTypeID
        }

        var showFieldPreview: Bool = true
        var lastUsedDeckID: UUID? = nil
        var lastUsedNoteTypeID: UUID? = nil

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            showFieldPreview = (try? container.decodeIfPresent(Bool.self, forKey: .showFieldPreview)) ?? true
            lastUsedDeckID = (try? container.decodeIfPresent(UUID.self, forKey: .lastUsedDeckID)) ?? nil
            lastUsedNoteTypeID = (try? container.decodeIfPresent(UUID.self, forKey: .lastUsedNoteTypeID)) ?? nil
        }
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

    struct UI: Content {
        enum CodingKeys: String, CodingKey {
            case prefersColorContrast
            case prefersDarkMode
        }

        var prefersColorContrast: Bool = false
        var prefersDarkMode: Bool = false

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            prefersColorContrast = (try? container.decodeIfPresent(Bool.self, forKey: .prefersColorContrast)) ?? false
            prefersDarkMode = (try? container.decodeIfPresent(Bool.self, forKey: .prefersDarkMode)) ?? false
        }
    }

    var anki = Anki()
    var reader = Reader()
    var ui = UI()

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anki = (try? container.decodeIfPresent(Anki.self, forKey: .anki)) ?? Anki()
        reader = (try? container.decodeIfPresent(Reader.self, forKey: .reader)) ?? Reader()
        ui = (try? container.decodeIfPresent(UI.self, forKey: .ui)) ?? UI()
    }

}
