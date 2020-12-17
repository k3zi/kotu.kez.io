struct SRTFileRoot: SubtitleFileRoot {

    static func canParse(tokenizer: Tokenizer) -> Bool {
        Subtitle.canParse(tokenizer: tokenizer)
    }

    // <root> ::= <sub-seq>
    // <sub-seq> ::= <sub> | <sub>\n\n<sub-seq>
    static func parse(tokenizer: Tokenizer) throws -> SRTFileRoot {
        var subtitles = [Subtitle]()
        while Subtitle.canParse(tokenizer: tokenizer) {
            subtitles.append(try Subtitle.parse(tokenizer: tokenizer))
            tokenizer.consume(while: "\n")
        }
        return .init(subtitles: subtitles)
    }

    func print(output: inout String) {
        for (i, subtitle) in subtitles.enumerated() {
            if i != 0 {
                output.append("\n\n")
            }
            subtitle.print(output: &output)
        }
    }

    static func encode(file: GenericSubtitleFile) -> SRTFileRoot {
        var subtitles = [Subtitle]()
        for (i, genericSubtitle) in file.subtitles.enumerated() {
            subtitles.append(.init(index: i, timeRange: .init(start: .init(milliseconds: genericSubtitle.start * 1000), end: .init(milliseconds: genericSubtitle.end * 1000)), displayCoordinate: nil, text: genericSubtitle.text))
        }
        return .init(subtitles: subtitles)
    }

    private let subtitles: [Subtitle]

}
