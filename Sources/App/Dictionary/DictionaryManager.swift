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

        let eDictURL = directoryURL.appendingPathComponent("../Dictionaries/misc/edict2u")
        var eDictWords = [String]()
        if let eDictString = try? String(contentsOf: eDictURL) {
            eDictWords = Array(eDictString.split(whereSeparator: \.isNewline).suffix(from: 1)).concurrentMap { string -> [String] in
                let properties = string.split(separator: "/")
                let cleaned = properties[0]
                    .replacingOccurrences(of: "[", with: ";")
                    .replacingOccurrences(of: "]", with: ";")
                    .replacingOccurrences(of: "(P)", with: "")
                return cleaned.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }.flatMap { $0 }
        }

        var frequencyList: [FrequencyListElement] = []
        let frequencyListURL = directoryURL.appendingPathComponent("../Dictionaries/frequency_lists/netflix/word_freq_report.txt")
        if let frequencyListString = try? String(contentsOf: frequencyListURL) {
            let arrays = frequencyListString.split(separator: "\r\n").concurrentMap { $0.split(separator: "\t").map { String($0) } }
            
            if let data = try? JSONEncoder().encode(arrays), let list = try? JSONDecoder().decode([FrequencyListElement].self, from: data) {
                frequencyList = list
            }
        }

        return Dictionary
            .query(on: app.db)
            .all()
            .map { $0.filter { !$0.directoryName.isEmpty }}
            .map { dictionaries in
                var containers = [String: CompressedFileContainer]()
                var cssStrings = [String: String]()
                var cssWordMappings = [String: [String: String]]()
                var contentIndexes = [String: ContentIndex]()
                var icons = [String: Data]()
                for dictionary in dictionaries {
                    icons[dictionary.directoryName] = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(dictionary.directoryName)/icon.png"))
                    let cssData = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(dictionary.directoryName)/style.css"))
                    var cssString = String(data: cssData, encoding: .utf8)!
                    let replacements = cssString.replaceNonASCIICharacters()

                    let contentsDirectory = directoryURL.appendingPathComponent("../Dictionaries/\(dictionary.directoryName)/contents")
                    let fileContainer = try! CompressedFileContainer(withDirectory: contentsDirectory)

                    let contentIndexData = try! Data(contentsOf: directoryURL.appendingPathComponent("../Dictionaries/\(dictionary.directoryName)/contents/contents.idx"))
                    let contentIndex = try! ContentIndex.parse(tokenizer: .init(data: contentIndexData))

                    containers[dictionary.directoryName] = fileContainer
                    cssStrings[dictionary.directoryName] = cssString
                    cssWordMappings[dictionary.directoryName] = replacements
                    contentIndexes[dictionary.directoryName] = contentIndex
                }

                _shared = .init(
                    containers: containers,
                    cssStrings: cssStrings,
                    cssWordMappings: cssWordMappings,
                    icons: icons,
                    contentIndexes: contentIndexes,
                    frequencyList: Swift.Dictionary(uniqueKeysWithValues: frequencyList.map { ($0.word, $0) }),
                    words: Set(eDictWords)
                )
            }
    }

    // MARK: Dictionary Items
    let containers: [String: CompressedFileContainer]
    let cssStrings: [String: String]
    let cssWordMappings: [String: [String: String]]
    let icons: [String: Data]
    let contentIndexes: [String: ContentIndex]

    // MARK: Misc
    let frequencyList: [String: FrequencyListElement]
    /// Just a list of all possible words we should consider.
    let words: Set<String>

}
