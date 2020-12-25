public struct HeadlineStore {

    public struct Headline: Encodable {
        public let index: UInt
        public let subindex: UInt
        public let text: String
    }

    public static func parse(tokenizer: DataTokenizer) throws -> HeadlineStore {
        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 2)
        let count = tokenizer.consumeInt32()
        print("count: \(count)")
        let offset = tokenizer.consumeInt32()
        print("offset: \(offset)")
        let secondSectionStart = tokenizer.consumeInt32()
        print("secondSectionStart: \(secondSectionStart)")
        try tokenizer.consumeInt32(expect: 24)
        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 0)

        var headlines = [Headline]()

        while tokenizer.currentOffset < secondSectionStart {
            let index = tokenizer.consumeInt32()
            let subindex = tokenizer.consumeInt32()
            let offset = secondSectionStart + tokenizer.consumeInt32()
            try tokenizer.consumeInt32(expect: 0)
            try tokenizer.consumeInt32(expect: 0)
            try tokenizer.consumeInt32(expect: 0)

            let headlineTokenizer = DataTokenizer(data: tokenizer.data[offset...])
            var utf8Array = headlineTokenizer.consume(times: 2)
            while utf8Array.last != .zero || utf8Array[utf8Array.count - 2] != .zero {
                utf8Array.append(contentsOf: headlineTokenizer.consume(maxTimes: 2))
            }
            let text = String(bytes: utf8Array[...(utf8Array.count - 2)], encoding: .utf16LittleEndian)!
            headlines.append(.init(index: UInt(index), subindex: UInt(subindex), text: text))
        }

        return .init(headlines: headlines)
    }

    public let headlines: [Headline]

}

