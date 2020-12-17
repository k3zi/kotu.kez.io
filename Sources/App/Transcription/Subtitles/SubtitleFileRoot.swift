protocol Parsable {
    static func canParse(tokenizer: Tokenizer) -> Bool
    static func parse(tokenizer: Tokenizer) throws -> Self
}

protocol Printable {
    func print(output: inout String)
}

protocol GenericEncodable {
    static func encode(file: GenericSubtitleFile) -> Self
}

protocol Elementable: Parsable, Printable {}
protocol SubtitleFileRoot: Elementable, GenericEncodable {}
