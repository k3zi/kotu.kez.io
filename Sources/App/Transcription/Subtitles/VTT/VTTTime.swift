extension VTTFileRoot.Subtitle.TimeRange {

    struct Time: Elementable {

        enum Error: Swift.Error {
            case invalidNumber
        }

        static func canParse(tokenizer: Tokenizer) -> Bool {
            tokenizer.next?.isNumber ?? false
        }

        // <time> ::= HH:MM:SS.MIL
        static func parse(tokenizer: Tokenizer) throws -> Time {
            let hoursString = try tokenizer.consume(times: 2)
            guard let hours = Double(hoursString) else {
                throw Error.invalidNumber
            }

            try tokenizer.consume(expect: ":")

            let minutesString = try tokenizer.consume(times: 2)
            guard let minutes = Double(minutesString) else {
                throw Error.invalidNumber
            }

            try tokenizer.consume(expect: ":")

            let secondsString = try tokenizer.consume(times: 2)
            guard let seconds = Double(secondsString) else {
                throw Error.invalidNumber
            }

            try tokenizer.consume(expect: ".")

            let millisecondsString = try tokenizer.consume(times: 3)

            guard let milliseconds = Double(millisecondsString) else {
                throw Error.invalidNumber
            }

            return .init(milliseconds: milliseconds + (1000 * seconds) + (1000 * 60 * minutes) + (1000 * 60 * 60 * hours))
        }

        func print(output: inout String) {
            let hours = self.milliseconds / (60 * 60 * 1000)
            let minutes = self.milliseconds.truncatingRemainder(dividingBy: 60 * 60 * 1000) / (60 * 1000)
            let seconds = (self.milliseconds.truncatingRemainder(dividingBy: 60 * 60 * 1000) / 1000).truncatingRemainder(dividingBy: 60)
            let milliseconds = self.milliseconds.truncatingRemainder(dividingBy: 1000)
            output.append(String(format: "%02i:%02i:%02i,%03i", Int(hours), Int(minutes), Int(seconds), Int(milliseconds)))
        }

        let milliseconds: Double
    }

}

