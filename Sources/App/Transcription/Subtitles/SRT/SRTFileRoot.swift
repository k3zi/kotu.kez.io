struct SRTFileRoot: SubtitleFileRoot {

    static func canParse(tokenizer: Tokenizer) -> Bool {
        Subtitle.canParse(tokenizer: tokenizer)
    }

    // <root> ::= <sub-seq>
    // <sub-seq> ::= <sub> | <sub>\n\n<sub-seq>
    static func parse(tokenizer: Tokenizer) throws -> SRTFileRoot {
        let subtitles = tokenizer.input.match("\\d\\d:\\d\\d:\\d\\d.\\d\\d\\d --> \\d\\d:\\d\\d:\\d\\d.\\d\\d\\d.*?\\n(?:.*?)\\n\\n").concurrentMap { try? Subtitle.parse(tokenizer: Tokenizer(input: $0[0])) }.compactMap { $0 }
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
            subtitles.append(.init(index: i + 1, timeRange: .init(start: .init(milliseconds: genericSubtitle.start * 1000), end: .init(milliseconds: genericSubtitle.end * 1000)), displayCoordinate: nil, text: genericSubtitle.text))
        }
        return .init(subtitles: subtitles)
    }

    let subtitles: [Subtitle]

}
