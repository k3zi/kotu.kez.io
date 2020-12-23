import Foundation

public struct ContentMap {

    public struct Pair: Equatable, Hashable {

        let index: Int

        let collectionIndex: Int

        /// The overall byte position of the file collection when everything is uncompressed.
        let collectionOffset: Int

        /// The byte position within the compressed file collection.
        let itemOffset: Int

        let itemIndex: Int
    }

    public static func parse(tokenizer: DataTokenizer) throws -> ContentMap {
        try tokenizer.consumeInt32(expect: 0)
        let count = tokenizer.consumeInt32()

        var pairs = [Pair]()
        var index = 1
        var collectionIndex = 0
        var itemIndex = 0
        var previousCollectionOffset: UInt32?

        while !tokenizer.reachedEnd {
            let collectionOffset = tokenizer.consumeInt32()
            let itemOffset = tokenizer.consumeInt32()

            if collectionOffset != previousCollectionOffset {
                collectionIndex += 1
                previousCollectionOffset = collectionOffset
                itemIndex = 1
            }

            print("\(index): \(collectionOffset)-\(itemOffset)")
            pairs.append(.init(index: index, collectionIndex: collectionIndex, collectionOffset: Int(collectionOffset), itemOffset: Int(itemOffset), itemIndex: itemIndex))
            itemIndex += 1
            index += 1
        }

        return .init(pairs: pairs)
    }

    public let pairs: [Pair]

}
