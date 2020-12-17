struct SSAFileRoot: SubtitleFileRoot {

    static func canParse(tokenizer: Tokenizer) -> Bool {
        fatalError()
    }

    static func parse(tokenizer: Tokenizer) throws -> SSAFileRoot {
        fatalError()
    }

    func print(output: inout String) {
        fatalError()
    }

    static func encode(file: GenericSubtitleFile) -> SSAFileRoot {
        fatalError()
    }

}
