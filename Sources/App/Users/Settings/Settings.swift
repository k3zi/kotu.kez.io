import Vapor

struct Settings: Content {

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
            case lastUsedTags
        }

        var keybinds: Keybinds = .init()
        var showFieldPreview: Bool = true
        var lastUsedDeckID: UUID? = nil
        var lastUsedNoteTypeID: UUID? = nil
        var lastUsedTags: [String] = .init()

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            keybinds = (try? container.decodeIfPresent(Keybinds.self, forKey: .keybinds)) ?? Keybinds()
            showFieldPreview = (try? container.decodeIfPresent(Bool.self, forKey: .showFieldPreview)) ?? true
            lastUsedDeckID = (try? container.decodeIfPresent(UUID.self, forKey: .lastUsedDeckID)) ?? nil
            lastUsedNoteTypeID = (try? container.decodeIfPresent(UUID.self, forKey: .lastUsedNoteTypeID)) ?? nil
            lastUsedTags = (try? container.decodeIfPresent([String].self, forKey: .lastUsedTags)) ?? []
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
                case minimalPairs
                case showFurigana
            }

            struct MinimalPairs: Content {
                enum CodingKeys: String, CodingKey {
                    case showContinueOnCorrect
                    case showContinueOnIncorrect
                }

                var showContinueOnCorrect: Bool = false
                var showContinueOnIncorrect: Bool = true

                init() { }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    showContinueOnCorrect = (try? container.decodeIfPresent(Bool.self, forKey: .showContinueOnCorrect)) ?? false
                    showContinueOnIncorrect = (try? container.decodeIfPresent(Bool.self, forKey: .showContinueOnIncorrect)) ?? true
                }
            }

            var minimalPairs = MinimalPairs()
            var showFurigana: Bool = true

            init() { }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                minimalPairs = (try? container.decodeIfPresent(MinimalPairs.self, forKey: .minimalPairs)) ?? MinimalPairs()
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
            case prefersCreateNoteOffcanvas
            case prefersDarkMode
            case prefersHorizontalText
        }

        var prefersColorContrast: Bool = false
        var prefersCreateNoteOffcanvas: Bool = false
        var prefersDarkMode: Bool = false
        var prefersHorizontalText: Bool = false

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            prefersColorContrast = (try? container.decodeIfPresent(Bool.self, forKey: .prefersColorContrast)) ?? false
            prefersCreateNoteOffcanvas = (try? container.decodeIfPresent(Bool.self, forKey: .prefersCreateNoteOffcanvas)) ?? false
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

    struct Scratchpad: Content {
        enum CodingKeys: String, CodingKey {
            case text
        }

        var text: String = ""

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
        }
    }

    struct YouTube: Content {

        struct Keybinds: Content {
            enum CodingKeys: String, CodingKey {
                case nextSubtitle
                case previousSubtitle
            }

            static let defaultNextSubtitle = Keybind.with(keys: ["ArrowRight"], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var nextSubtitle: Keybind = Self.defaultNextSubtitle

            static let defaultPreviousSubtitle = Keybind.with(keys: ["ArrowLeft"], ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
            var previousSubtitle: Keybind = Self.defaultPreviousSubtitle

            init() { }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                nextSubtitle = (try? container.decodeIfPresent(Keybind.self, forKey: .nextSubtitle)) ?? Self.defaultNextSubtitle
                previousSubtitle = (try? container.decodeIfPresent(Keybind.self, forKey: .previousSubtitle)) ?? Self.defaultPreviousSubtitle
            }
        }

        enum CodingKeys: String, CodingKey {
            case keybinds
        }

        var keybinds: Keybinds = .init()

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            keybinds = (try? container.decodeIfPresent(Keybinds.self, forKey: .keybinds)) ?? .init()
        }
    }

    enum CodingKeys: String, CodingKey {
        case anki
        case reader
        case scratchpad
        case tests
        case ui
        case wordStatus
        case youTube
    }

    var anki = Anki()
    var reader = Reader()
    var scratchpad = Scratchpad()
    var tests = Tests()
    var ui = UI()
    var wordStatus = WordStatus()
    var youTube = YouTube()

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anki = (try? container.decodeIfPresent(Anki.self, forKey: .anki)) ?? Anki()
        reader = (try? container.decodeIfPresent(Reader.self, forKey: .reader)) ?? Reader()
        scratchpad = (try? container.decodeIfPresent(Scratchpad.self, forKey: .scratchpad)) ?? Scratchpad()
        tests = (try? container.decodeIfPresent(Tests.self, forKey: .tests)) ?? Tests()
        ui = (try? container.decodeIfPresent(UI.self, forKey: .ui)) ?? UI()
        wordStatus = (try? container.decodeIfPresent(WordStatus.self, forKey: .wordStatus)) ?? WordStatus()
        youTube = (try? container.decodeIfPresent(YouTube.self, forKey: .youTube)) ?? YouTube()
    }

}
