import Foundation

struct SubtitleFile {

    enum Error: Swift.Error {
        case fileContentsCouldNotBeParsed
        case couldNotDetectFileType
        case invalidKind
    }

    enum Kind: String, CaseIterable, Equatable, RawRepresentable, LosslessStringConvertible {

        init?(_ description: String) {
            self.init(rawValue: description)
        }

        var description: String {
            switch self {
            case .detect: return "detect"
            case .ssa: return "ssa"
            case .ass: return "ass"
            case .srt: return "srt"
            }
        }

        case detect

        case ssa
        case ass
        case srt

        var rootType: SubtitleFileRoot.Type {
            switch self {
            case .detect: fatalError()
            case .ssa: return SSAFileRoot.self
            case .ass: return ASSFileRoot.self
            case .srt: return SRTFileRoot.self
            }
        }

        var fileExtension: String {
            switch self {
            case .detect: return ""
            case .ssa: return "ssa"
            case .ass: return "ass"
            case .srt: return "srt"
            }
        }

        static func `for`(extension ext: String) -> Kind? {
            switch ext {
            case "ssa": return .ssa
            case "ass": return .ass
            case "srt": return .srt
            default: return nil
            }
        }

    }

    let root: SubtitleFileRoot

    init(file: URL, encoding: String.Encoding = .unicode, kind: Kind = .detect) throws {
        let contents = try Data(contentsOf: file)
        let stringContents = String(data: contents, encoding: encoding)
        guard let string = stringContents else {
            throw Error.fileContentsCouldNotBeParsed
        }
        if kind == .detect {
            let extensionKind = Kind.for(extension: file.pathExtension)
            let result = extensionKind.flatMap { try? $0.rootType.parse(tokenizer: Tokenizer(input: string)) } ?? Kind.allCases.filter { $0 != .detect && $0 != extensionKind }.map { try? $0.rootType.parse(tokenizer: Tokenizer(input: string)) }.first { $0 != nil }
            guard let unwrappedResult = result.flatMap({ $0 }) else {
                throw Error.couldNotDetectFileType
            }
            root = unwrappedResult
        } else {
            root = try kind.rootType.parse(tokenizer: Tokenizer(input: string))
        }
    }

    init(file: GenericSubtitleFile, kind: Kind = .detect) throws {
        guard kind != .detect else { throw Error.invalidKind }
        root = kind.rootType.encode(file: file)
    }

    func asString() -> String {
        var output = ""
        root.print(output: &output)
        return output
    }

}
