struct Range {

    static func parse(tokenizer: Tokenizer) throws -> Range {
        try tokenizer.consume(expect: "bytes")
        try tokenizer.consume(expect: "=")
        let start = tokenizer.consume(upUntil: "-")
        try tokenizer.consume(expect: "-")
        let end = tokenizer.consume(while: { _,_ in true })
        return Range(startByte: Int(start) ?? 0, endByte: Int(end) ?? .max)
    }

    let startByte: Int
    let endByte: Int

}
