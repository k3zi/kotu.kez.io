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

    static var shared: DictionaryManager = {
        let directory = DirectoryConfiguration.detect().workingDirectory
        let directoryURL = URL(fileURLWithPath: directory)

        let cssData = try! Data(contentsOf: directoryURL.appendingPathComponent("Resources/Dictionaries/SMK8/SMK8.css"))
        var cssString = String(data: cssData, encoding: .utf8)!
        let replacements = cssString.replaceNonASCIICharacters()

        let contentsDirectory = directoryURL.appendingPathComponent("Resources/Dictionaries/SMK8/contents")
        let fileContainer = try! CompressedFileContainer(withDirectory: contentsDirectory)

        return .init(
            containers: ["SMK8": fileContainer],
            cssStrings: ["SMK8": cssString],
            cssWordMappings: ["SMK8": replacements]
        )
    }()

    static func preload() {
        _ = DictionaryManager.shared
    }

    let containers: [String: CompressedFileContainer]
    let cssStrings: [String: String]
    let cssWordMappings: [String: [String: String]]

}
