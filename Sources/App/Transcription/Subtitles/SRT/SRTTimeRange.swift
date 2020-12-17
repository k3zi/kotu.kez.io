extension SRTFileRoot.Subtitle {

    struct TimeRange: Elementable {

        static func canParse(tokenizer: Tokenizer) -> Bool {
            Time.canParse(tokenizer: tokenizer)
        }

        // <time-range> ::= <time> --> <time>
        static func parse(tokenizer: Tokenizer) throws -> SRTFileRoot.Subtitle.TimeRange {
            let start = try Time.parse(tokenizer: tokenizer)
            try tokenizer.consume(expect: " ")
            try tokenizer.consume(expect: "-")
            try tokenizer.consume(expect: "-")
            try tokenizer.consume(expect: ">")
            try tokenizer.consume(expect: " ")
            let end = try Time.parse(tokenizer: tokenizer)
            return .init(start: start, end: end)
        }

        func print(output: inout String) {
            start.print(output: &output)
            output.append(" --> ")
            end.print(output: &output)
        }

        let start: Time
        let end: Time
    }

}
