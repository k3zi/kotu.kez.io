struct ASSFileRoot: SubtitleFileRoot {

    static func canParse(tokenizer: Tokenizer) -> Bool {
        fatalError()
    }

    static func parse(tokenizer: Tokenizer) throws -> ASSFileRoot {
        fatalError()
    }

    func print(output: inout String) {
        fatalError()
    }

    static func encode(file: GenericSubtitleFile) -> ASSFileRoot {
        fatalError()
    }

}
