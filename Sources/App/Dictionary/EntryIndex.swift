import Foundation

public struct ListIndex {

    public struct Item: Equatable, Hashable {

        let entryIndex: Int
        let subentryIndex: Int

    }

    public static func parse(tokenizer: DataTokenizer) throws -> Self {
        _ = tokenizer.consumeInt32() // count of entries
        tokenizer.consume(times: 4 * 8)

        var items = [Item]()

        while !tokenizer.reachedEnd {
            let entryIndex = tokenizer.consumeInt32()
            let subentryIndex = tokenizer.consumeInt32()
            items.append(.init(entryIndex: Int(entryIndex), subentryIndex: Int(subentryIndex)))
        }

        return .init(items: items)
    }

    public let items: [Item]

}
