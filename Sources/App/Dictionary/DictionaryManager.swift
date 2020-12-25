import Vapor

extension String {

    @discardableResult
    mutating func replaceNonASCIICharacters() -> [String: String] {
        var replacements = [String: String]()
        while let range = self.range(of: #"[^abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890\\/\*"\,\-_\+=@ #;\n\{\}\t\:\.<>]+"#, options: .regularExpression) {
            let string = self[range]
            let replacement = string.data(using: .utf8)!.base32EncodedString().replacingOccurrences(of: "=", with: "x").lowercased()
            let prefixedReplacement = "x\(replacement)"
            replacements[String(string)] = prefixedReplacement
            self.replaceSubrange(range, with: prefixedReplacement)
        }
        return replacements
    }

    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }

    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }

    func encodeForHTML() -> String {
        data(using: .utf8)!.base32EncodedString().replacingOccurrences(of: "=", with: "x").lowercased()
    }

    mutating func replaceNonASCIIHTMLNodes() {
        let invalidGroup = #"[^abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890\\/\*"\,\-_\+=@ \?$#;\n\{\}\t\:\.<>]"#
        let validGroup = #"[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890=" \-_]"#
        func replace(_ regex: String, _ replacementModifier: (String) -> String) {
            while let range = self.range(of: regex, options: .regularExpression) {
                let string = self[range]
                let prefixedReplacement = replacementModifier(String(string))
                self.replaceSubrange(range, with: prefixedReplacement)
            }
        }

        replace("<\(invalidGroup)+\(validGroup)*? ", { "<x\($0[1..<($0.count - 1)].encodeForHTML()) " })
        replace("<\(invalidGroup)+\(validGroup)*?>", { "<x\($0[1..<($0.count - 1)].encodeForHTML())>" })
        replace("</\(invalidGroup)+\(validGroup)*? ", { "</x\($0[2..<($0.count - 1)].encodeForHTML()) " })
        replace("</\(invalidGroup)+\(validGroup)*?>", { "</x\($0[2..<($0.count - 1)].encodeForHTML())>" })
        replace("\"\(invalidGroup)+\(validGroup)*?\"", { "\"x\($0[1..<($0.count - 1)].encodeForHTML())\"" })
    }

}

struct DictionaryManager {

    fileprivate static var _shared: DictionaryManager?

    static var shared: DictionaryManager {
        return _shared!
    }

    static func configure(app: Application) -> EventLoopFuture<Void> {
        let directory = app.directory.workingDirectory
        let directoryURL = URL(fileURLWithPath: directory)

        return Dictionary
            .query(on: app.db)
            .all()
            .map { dictionaries in
                var containers = [String: CompressedFileContainer]()
                var cssStrings = [String: String]()
                var cssWordMappings = [String: [String: String]]()
                for dictionary in dictionaries {
                    let cssData = try! Data(contentsOf: directoryURL.appendingPathComponent("Resources/Dictionaries/\(dictionary.directoryName)/style.css"))
                    var cssString = String(data: cssData, encoding: .utf8)!
                    let replacements = cssString.replaceNonASCIICharacters()

                    let contentsDirectory = directoryURL.appendingPathComponent("Resources/Dictionaries/SMK8/contents")
                    let fileContainer = try! CompressedFileContainer(withDirectory: contentsDirectory)
                    containers[dictionary.directoryName] = fileContainer
                    cssStrings[dictionary.directoryName] = cssString
                    cssWordMappings[dictionary.directoryName] = replacements
                }

                _shared = .init(
                    containers: containers,
                    cssStrings: cssStrings,
                    cssWordMappings: cssWordMappings
                )
            }
    }

    let containers: [String: CompressedFileContainer]
    let cssStrings: [String: String]
    let cssWordMappings: [String: [String: String]]

}
