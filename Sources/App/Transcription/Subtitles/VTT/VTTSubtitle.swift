extension VTTFileRoot {

    struct Subtitle: Elementable {

        typealias DisplayCoordinate = SRTFileRoot.Subtitle.DisplayCoordinate

        enum Error: Swift.Error {
            case invalidIndex
        }

        static func canParse(tokenizer: Tokenizer) -> Bool {
            tokenizer.next?.isNumber ?? false
        }

        // <sub> ::= <index>\n<time-range>
        //       ::= <index>\n<time-range>\n<text-seq>
        //       ::= <index>\n<time-range> <display-coordinate>
        //       ::= <index>\n<time-range> <display-coordinate>\n<text-seq>
        static func parse(tokenizer: Tokenizer) throws -> Subtitle {
            let timeRange = try TimeRange.parse(tokenizer: tokenizer)

            tokenizer.consume(upUntil: "\n")

            var text = ""
            if tokenizer.next == "\n" && tokenizer.nextNext != "\n" {
                try tokenizer.consume(expect: "\n")
                text = tokenizer.consume(upUntil: { n, nn in n == "\n" && nn == "\n" })
            }

            return .init(timeRange: timeRange, displayCoordinate: nil, text: text)
        }

        func print(output: inout String) {
            timeRange.print(output: &output)
            if let displayCoordinate = displayCoordinate {
                output.append(" ")
                displayCoordinate.print(output: &output)
            }
            output.append("\n")
            output.append(text)
        }

        let timeRange: TimeRange
        let displayCoordinate: DisplayCoordinate?
        let text: String

    }

}
