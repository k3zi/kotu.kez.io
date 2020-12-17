extension SRTFileRoot.Subtitle {

    struct DisplayCoordinate: Elementable {

        enum Error: Swift.Error {
            case invalidNumber
        }

        static func canParse(tokenizer: Tokenizer) -> Bool {
            tokenizer.next == "X"
        }

        // <display-coordinate> ::= X1:<int> X2:<int> Y1:<int> Y2:<int>
        static func parse(tokenizer: Tokenizer) throws -> SRTFileRoot.Subtitle.DisplayCoordinate {
            try tokenizer.consume(expect: "X1")
            try tokenizer.consume(expect: ":")
            let x1String = tokenizer.consume { $0.isNumber }
            guard let x1 = Int(x1String) else { throw Error.invalidNumber }
            try tokenizer.consume(expect: " ")

            try tokenizer.consume(expect: "X2")
            try tokenizer.consume(expect: ":")
            let x2String = tokenizer.consume { $0.isNumber }
            guard let x2 = Int(x2String) else { throw Error.invalidNumber }
            try tokenizer.consume(expect: " ")

            try tokenizer.consume(expect: "Y1")
            try tokenizer.consume(expect: ":")
            let y1String = tokenizer.consume { $0.isNumber }
            guard let y1 = Int(y1String) else { throw Error.invalidNumber }
            try tokenizer.consume(expect: " ")

            try tokenizer.consume(expect: "Y2")
            try tokenizer.consume(expect: ":")
            let y2String = tokenizer.consume { $0.isNumber }
            guard let y2 = Int(y2String) else { throw Error.invalidNumber }

            return .init(x1: x1, x2: x2, y1: y1, y2: y2)
        }

        func print(output: inout String) {
            output.append("X1:\(x1) X2:\(x2) Y1:\(y1) Y2:\(y2)")
        }

        private let x1: Int
        private let x2: Int
        private let y1: Int
        private let y2: Int
    }

}
