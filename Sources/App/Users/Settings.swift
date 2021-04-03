import Vapor

struct Settings: Content {

    enum Keybind: Content {

        enum CodingKeys: String, CodingKey {
            case keys
            case ctrlKey
            case shiftKey
            case altKey
            case metaKey
        }

        case with(keys: [String], ctrlKey: Bool, shiftKey: Bool, altKey: Bool, metaKey: Bool)
        case disabled

        init(from decoder: Decoder) throws {
            let singleValueContainer = try? decoder.singleValueContainer()
            if let stringValue = try? singleValueContainer?.decode(String.self), stringValue == "disabled" {
                self = .disabled
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let keys = try container.decode([String].self, forKey: .keys)
                let ctrlKey = try container.decode(Bool.self, forKey: .ctrlKey)
                let shiftKey = try container.decode(Bool.self, forKey: .shiftKey)
                let altKey = try container.decode(Bool.self, forKey: .altKey)
                let metaKey = try container.decode(Bool.self, forKey: .metaKey)
                self = .with(keys: keys, ctrlKey: ctrlKey, shiftKey: shiftKey, altKey: altKey, metaKey: metaKey)
            }
        }

        func encode(to encoder: Encoder) throws {
            switch self {
            case .with(keys: let keys, ctrlKey: let ctrlKey, shiftKey: let shiftKey, altKey: let altKey, metaKey: let metaKey):
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(keys, forKey: .keys)
                try container.encode(ctrlKey, forKey: .ctrlKey)
                try container.encode(shiftKey, forKey: .shiftKey)
                try container.encode(altKey, forKey: .altKey)
                try container.encode(metaKey, forKey: .metaKey)
            case .disabled:
                var container = encoder.singleValueContainer()
                try container.encode("disabled")
            }
        }
    }

    struct Anki: Content {

        struct Keybinds: Content {
            enum CodingKeys: String, CodingKey {
                case showAnswer
                case grade0
                case grade1
                case grade2
                case grade3
                case grade4
                case grade5
            }

            static let defaultShowAnswer = Keybind.with(keys: [" "], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var showAnswer: Keybind = Self.defaultShowAnswer

            static let defaultGrade0 = Keybind.with(keys: ["0"], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var grade0: Keybind = Self.defaultGrade0

            static let defaultGrade1 = Keybind.with(keys: ["1"], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var grade1: Keybind = Self.defaultGrade1

            static let defaultGrade2 = Keybind.with(keys: ["2"], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var grade2: Keybind = Self.defaultGrade2

            static let defaultGrade3 = Keybind.with(keys: ["3"], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var grade3: Keybind = Self.defaultGrade3

            static let defaultGrade4 = Keybind.with(keys: ["4"], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var grade4: Keybind = Self.defaultGrade4

            static let defaultGrade5 = Keybind.with(keys: ["5"], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var grade5: Keybind = Self.defaultGrade5

            init() { }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                showAnswer = (try? container.decodeIfPresent(Keybind.self, forKey: .showAnswer)) ?? Self.defaultShowAnswer
                grade0 = (try? container.decodeIfPresent(Keybind.self, forKey: .grade0)) ?? Self.defaultGrade0
                grade1 = (try? container.decodeIfPresent(Keybind.self, forKey: .grade1)) ?? Self.defaultGrade1
                grade2 = (try? container.decodeIfPresent(Keybind.self, forKey: .grade2)) ?? Self.defaultGrade2
                grade3 = (try? container.decodeIfPresent(Keybind.self, forKey: .grade3)) ?? Self.defaultGrade3
                grade4 = (try? container.decodeIfPresent(Keybind.self, forKey: .grade4)) ?? Self.defaultGrade4
                grade5 = (try? container.decodeIfPresent(Keybind.self, forKey: .grade5)) ?? Self.defaultGrade5
            }
        }

        enum CodingKeys: String, CodingKey {
            case keybinds
            case showFieldPreview
            case lastUsedDeckID
            case lastUsedNoteTypeID
        }

        var keybinds: Keybinds = .init()
        var showFieldPreview: Bool = true
        var lastUsedDeckID: UUID? = nil
        var lastUsedNoteTypeID: UUID? = nil

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            keybinds = (try? container.decodeIfPresent(Keybinds.self, forKey: .keybinds)) ?? Keybinds()
            showFieldPreview = (try? container.decodeIfPresent(Bool.self, forKey: .showFieldPreview)) ?? true
            lastUsedDeckID = (try? container.decodeIfPresent(UUID.self, forKey: .lastUsedDeckID)) ?? nil
            lastUsedNoteTypeID = (try? container.decodeIfPresent(UUID.self, forKey: .lastUsedNoteTypeID)) ?? nil
        }
    }

    struct Reader: Content {
        enum CodingKeys: String, CodingKey {
            case autoplay
            case autoplayDelay
            case autoplayScroll
            case showCreateNoteForm
        }

        var autoplay: Bool = true
        var autoplayDelay: Float = 2
        var autoplayScroll: Bool = true
        var showCreateNoteForm: Bool = true

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            autoplay = (try? container.decodeIfPresent(Bool.self, forKey: .autoplay)) ?? true
            autoplayDelay = (try? container.decodeIfPresent(Float.self, forKey: .autoplayDelay)) ?? 2
            autoplayScroll = (try? container.decodeIfPresent(Bool.self, forKey: .autoplayScroll)) ?? true
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
