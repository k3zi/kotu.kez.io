import Foundation

public struct ContentIndex {

    public struct Pair: Equatable, Hashable {

        let fromIndex: Int
        let toIndex: Int

    }

    public static func parse(tokenizer: DataTokenizer) throws -> ContentIndex {
        let count = tokenizer.consumeInt32()
        try tokenizer.consumeInt32(expect: 0)

        var mapping = [Int: Int]()

        while !tokenizer.reachedEnd {
            let from = tokenizer.consumeInt32()
            let to = tokenizer.consumeInt32()
            mapping[Int(from)] = Int(to)
        }

        return .init(indexMapping: mapping)
    }

    public let indexMapping: [Int: Int]

}
