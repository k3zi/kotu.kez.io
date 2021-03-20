import Foundation
import Gzip

extension UInt8 {

    var power2Exponent: Int {
        switch self {
        case 0:
            return 0
        case 1:
            return 1
        case 2:
            return 2
        case 4:
            return 3
        default:
            fatalError()
        }
    }

}

extension Array where Element == KeyStore.Match {

    public static func parse(tokenizer: DataTokenizer) throws -> Self {
        let count = tokenizer.consume()
        try tokenizer.consume(expect: 0)
        var matches = [KeyStore.Match]()
        for _ in 0..<count {
            let header = tokenizer.consume()
            // Ends in 1
            let hexStringArray = Array<Character>(String(format:"%02X", header))
            let subentryNumberOfBytes = UInt8(String(hexStringArray[0]), radix: 16)!.power2Exponent
            let numberOfBytes = UInt8(String(hexStringArray[1]), radix: 16)!.power2Exponent

            var match = tokenizer.consume(times: numberOfBytes)
            while !match.count.isMultiple(of: 4) {
                match.insert(.zero, at: 0)
            }
            let entryIndex = UInt32(bigEndian: match.withUnsafeBufferPointer {
                ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
            }.pointee)
            var subentryIndex: UInt = 0
            if subentryNumberOfBytes > 0 {
                var match = tokenizer.consume(times: subentryNumberOfBytes)
                while !match.count.isMultiple(of: 4) {
                    match.insert(.zero, at: 0)
                }
                subentryIndex = UInt(UInt32(bigEndian: match.withUnsafeBufferPointer {
                    ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
                }.pointee))
            }
            matches.append(KeyStore.Match(entryIndex: UInt(entryIndex), subentryIndex: subentryIndex))
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

    public static func parse(dictionaryFolder: URL) throws -> KeyStore? {
        let keyFolder = dictionaryFolder.appendingPathComponent("key")
        if FileManager.default.fileExists(atPath: keyFolder.path) {
            let keystoreFile = keyFolder.appendingPathComponent("headword.keystore")
            if FileManager.default.fileExists(atPath: keystoreFile.path) {
                let data = try Data(contentsOf: keystoreFile)
                return try Self.parse(tokenizer: DataTokenizer(data: data))
            }

            let rscFileURLs = try FileManager.default.contentsOfDirectory(at: keyFolder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "rsc" }
                .sorted(by: { $0.path < $1.path })

            if rscFileURLs.count > 0 {
                return try Self.parseRSCs(files: rscFileURLs)
            }

            return nil
        } else {
            return nil
        }
    }

    public static func parseRSCs(files: [URL]) throws -> KeyStore {
        var pairs = [Pair]()
        for file in files {
            let data = try Data(contentsOf: file)
            let tokenizer = DataTokenizer(data: data)
            while !tokenizer.reachedEnd {
                tokenizer.consumeInt32()
                let lengthOfText = tokenizer.consumeInt16()
                let numberOfMatches = tokenizer.consumeInt16()
                var matches = [KeyStore.Match]()

                if numberOfMatches == .zero {
                    fatalError()
                }

                for _ in (0..<numberOfMatches) {
                    let entryIndex = tokenizer.consumeInt32()
                    let subentryIndex = tokenizer.consumeInt32()

                    matches.append(KeyStore.Match(entryIndex: UInt(entryIndex), subentryIndex: UInt(subentryIndex)))
                }

                let textArray = tokenizer.consume(times: Int(lengthOfText) * 2)
                tokenizer.consumeUntil(nextByteGroupOf: 4)
                let text = String(bytes: textArray, encoding: .utf16LittleEndian)!
                pairs.append(Pair(value: text, matches: matches))
            }
        }

        return .init(pairs: pairs)
    }

    public static func parse(tokenizer: DataTokenizer) throws -> KeyStore {
        let _ = tokenizer.consumeInt32()
        try tokenizer.consumeInt32(expect: 0)
        let offset = tokenizer.consumeInt32()
        let startOfThirdSection = tokenizer.consumeInt32()

        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 0)

        let _ = tokenizer.consumeInt32()
        let dataStartIndex = tokenizer.consumeInt32()
        var dataIndices = [dataStartIndex]
        while tokenizer.currentOffset < (dataStartIndex + offset) {
            dataIndices.append(tokenizer.consumeInt32())
        }
        var pairs = [Pair]()
        for i in 0..<dataIndices.count {
            let index = tokenizer.consumeInt32() + offset
            tokenizer.consume() // can be a 1 or 0 but probably a 0 (way of counting sub headwords?)
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

