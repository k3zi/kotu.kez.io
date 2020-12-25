import Foundation
import Gzip

extension Array where Element == KeyStore.Match {

    public static func parse(tokenizer: DataTokenizer) throws -> Self {
        let count = tokenizer.consume()
        try tokenizer.consume(expect: 0)
        var matches = [KeyStore.Match]()
        for _ in 0..<count {
            let header = tokenizer.consume()
            // Ends in 1
            let hexStringArray = Array<Character>(String(format:"%02X", header))
            let isSubentry = UInt8(String(hexStringArray[0]), radix: 16)!
            let bytesToExpect = UInt8(String(hexStringArray[1]), radix: 16)!
            let hasSubentry: Bool
            if isSubentry == 1 {
                hasSubentry = true
            } else if isSubentry == 0 {
                hasSubentry = false
            } else {
                // Does this case ever get hit?
                fatalError()
            }

            var match = tokenizer.consume(times: Int(bytesToExpect))
            while !match.count.isMultiple(of: 4) {
                match.insert(.zero, at: 0)
            }
            let entryIndex = UInt32(bigEndian: match.withUnsafeBufferPointer {
                ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
            }.pointee)
            let subentryIndex = hasSubentry ? tokenizer.consume() : 0
            matches.append(KeyStore.Match(entryIndex: UInt(entryIndex), subentryIndex: UInt(subentryIndex)))
        }

        return matches
    }

}

public struct KeyStore {

    public struct Pair {
        public let value: String
        public let matches: [Match]
    }

    public struct Match {
        public let entryIndex: UInt
        public let subentryIndex: UInt
    }

    public static func parse(tokenizer: DataTokenizer) throws -> KeyStore {
        let unknown1 = tokenizer.consumeInt32()
        try tokenizer.consumeInt32(expect: 0)
        let offset = tokenizer.consumeInt32()
        let startOfThirdSection = tokenizer.consumeInt32()

        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 0)

        let count = tokenizer.consumeInt32()
        let dataStartIndex = tokenizer.consumeInt32()
        var dataIndices = [dataStartIndex]
        while tokenizer.currentOffset < (dataStartIndex + offset) {
            dataIndices.append(tokenizer.consumeInt32())
        }
        var pairs = [Pair]()
        for i in 0..<dataIndices.count {
            let index = tokenizer.consumeInt32() + offset
            try tokenizer.consume(expect: 0)
            var utf8Array = tokenizer.consume(times: 3)
            while utf8Array.last != .zero || utf8Array[utf8Array.count - 2] != .zero {
                utf8Array.append(contentsOf: tokenizer.consume(times: 4))
            }
            let text = String(bytes: utf8Array.dropLast { $0 == .zero }, encoding: .utf8)!
            var matchData: Data
            if (i+1) != dataIndices.count {
                let endIndex = tokenizer.nextInt32 + offset
                matchData = tokenizer.data[index..<endIndex]
            } else {
                matchData = tokenizer.data[index..<startOfThirdSection]
            }

            let matchTokenizer = DataTokenizer(data: matchData)
            let matches = try [Match].parse(tokenizer: matchTokenizer)
            pairs.append(Pair(value: text, matches: matches))
            //print("\(text) @ \(matches.map { "\($0.entryIndex)-\($0.subentryIndex)" }.joined(separator: ", "))")
        }

        return .init(pairs: pairs)
    }

    public let pairs: [Pair]

}

extension Array {

    func dropLast(while handler: (Element) -> Bool) -> Array {
        var array = self
        while let last = array.last, handler(last) {
            array.removeLast()
        }
        return array
    }

    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

}

