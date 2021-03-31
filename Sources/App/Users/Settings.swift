import Vapor

struct Settings: Content {

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
            case autoplayDelay
            case showCreateNoteForm
        }

        var autoplayDelay: Float = 2
        var showCreateNoteForm: Bool = true

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            autoplayDelay = (try? container.decodeIfPresent(Float.self, forKey: .autoplayDelay)) ?? 2
            showCreateNoteForm = (try? container.decodeIfPresent(Bool.self, forKey: .showCreateNoteForm)) ?? true
        }
    }

    struct Tests: Content {
        enum CodingKeys: String, CodingKey {
            case pitchAccent
        }

        struct PitchAccent: Content {
            enum CodingKeys: String, CodingKey {
                case showFurigana
            }

            var showFurigana: Bool = true

            init() { }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                showFurigana = (try? container.decodeIfPresent(Bool.self, forKey: .showFurigana)) ?? true
            }
        }

        var pitchAccent = PitchAccent()

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            pitchAccent = (try? container.decodeIfPresent(PitchAccent.self, forKey: .pitchAccent)) ?? PitchAccent()
        }
    }

    struct UI: Content {
        enum CodingKeys: String, CodingKey {
            case prefersColorContrast
            case prefersDarkMode
            case prefersHorizontalText
        }

        var prefersColorContrast: Bool = false
        var prefersDarkMode: Bool = false
        var prefersHorizontalText: Bool = false

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            prefersColorContrast = (try? container.decodeIfPresent(Bool.self, forKey: .prefersColorContrast)) ?? false
            prefersDarkMode = (try? container.decodeIfPresent(Bool.self, forKey: .prefersDarkMode)) ?? false
            prefersHorizontalText = (try? container.decodeIfPresent(Bool.self, forKey: .prefersHorizontalText)) ?? false
        }
    }

    struct WordStatus: Content {
        enum CodingKeys: String, CodingKey {
            case isEnabled
        }

        var isEnabled: Bool = false

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? false
        }
    }

    enum CodingKeys: String, CodingKey {
        case anki
        case reader
        case tests
        case ui
        case wordStatus
    }

    var anki = Anki()
    var reader = Reader()
    var tests = Tests()
    var ui = UI()
    var wordStatus = WordStatus()

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anki = (try? container.decodeIfPresent(Anki.self, forKey: .anki)) ?? Anki()
        reader = (try? container.decodeIfPresent(Reader.self, forKey: .reader)) ?? Reader()
        tests = (try? container.decodeIfPresent(Tests.self, forKey: .tests)) ?? Tests()
        ui = (try? container.decodeIfPresent(UI.self, forKey: .ui)) ?? UI()
        wordStatus = (try? container.decodeIfPresent(WordStatus.self, forKey: .wordStatus)) ?? WordStatus()
    }

}
