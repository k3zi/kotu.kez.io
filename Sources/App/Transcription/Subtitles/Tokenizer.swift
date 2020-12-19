class Tokenizer {

    enum Error: Swift.Error {
        case expected(Character)
        case expectedString(String)
        case ranOutOfInput
    }

    var input: String

    init(input: String) {
        self.input = input
    }

    @discardableResult
    func consume() -> Character {
        input.removeFirst()
    }

    func consume(expect character: Character) throws {
        if consume() != character {
            throw Error.expected(character)
        }
    }

    func ifConsume(expect character: Character, _ branch: () throws -> ()) rethrows {
        if next == character {
            consume()
            try branch()
        }
    }

    func consume(expect string: String) throws {
        if try consume(times: string.count) != string {
            throw Error.expectedString(string)
        }
    }

    @discardableResult
    func consume(times: Int) throws -> String {
        guard input.count >= times else {
            throw Error.ranOutOfInput
        }

        var result = ""
        while result.count != times {
            result.append(consume())
        }
        return result
    }

    @discardableResult
    func consume(while condition: (Character, Character?) -> Bool) -> String {
        var result = ""
        while let next = next, condition(next, nextNext) {
            result.append(consume())
        }
        return result
    }

    func consume(while character: Character) {
        consume(while: { n, _ in n == character })
    }

    @discardableResult
    func consume(upUntil stopCharacter: Character) -> String {
        consume(upUntil: { n, _ in n == stopCharacter })
    }

    @discardableResult
    func consume(upUntil condition: (Character, Character?) -> Bool) -> String {
        consume(while: { !condition($0, $1) })
    }

    var next: Character? {
        input.first
    }

    var nextNext: Character? {
        input.count > 1 ? input[input.index(after: input.startIndex)] : nil
    }

}
