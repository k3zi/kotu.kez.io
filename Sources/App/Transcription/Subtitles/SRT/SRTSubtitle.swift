extension SRTFileRoot {

    struct Subtitle: Elementable {

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
        static func parse(tokenizer: Tokenizer) throws -> SRTFileRoot.Subtitle {
            let indexString = tokenizer.consume(upUntil: "\n")
            guard let index = Int(indexString) else {
                throw Error.invalidIndex
            }

            try tokenizer.consume(expect: "\n")

            let timeRange = try TimeRange.parse(tokenizer: tokenizer)

            var displayCoordinate: DisplayCoordinate?
            try tokenizer.ifConsume(expect: " ") {
                displayCoordinate = try DisplayCoordinate.parse(tokenizer: tokenizer)
            }

            var text = ""
            if tokenizer.next == "\n" && tokenizer.nextNext != "\n" {
                try tokenizer.consume(expect: "\n")
                text = tokenizer.consume(upUntil: { n, nn in n == "\n" && nn == "\n" })
            }

            return .init(index: index, timeRange: timeRange, displayCoordinate: displayCoordinate, text: text)
        }

        func print(output: inout String) {
            output.append(String(index))
            output.append("\n")
            timeRange.print(output: &output)
            if let displayCoordinate = displayCoordinate {
                output.append(" ")
                displayCoordinate.print(output: &output)
            }
            output.append("\n")
            output.append(text)
        }

        let index: Int
        let timeRange: TimeRange
        let displayCoordinate: DisplayCoordinate?
        let text: String

    }

}
