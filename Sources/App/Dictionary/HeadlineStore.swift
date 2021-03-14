import Foundation

public struct HeadlineStore {

    public struct Headline: Encodable {
        public let index: UInt
        public let subindex: UInt
        public let text: String
    }

    public static func parse(dictionaryFolder: URL, short: Bool = false) throws -> HeadlineStore? {
        let headlineFolder = dictionaryFolder.appendingPathComponent("headline")
        if FileManager.default.fileExists(atPath: headlineFolder.path) {
            let headlineStoreFile = headlineFolder.appendingPathComponent(short ? "short-headline.headlinestore" : "headline.headlinestore")
            if FileManager.default.fileExists(atPath: headlineStoreFile.path) {
                let headlineStoreData = try Data(contentsOf: headlineStoreFile)
                return try Self.parse(tokenizer: DataTokenizer(data: headlineStoreData))
            }

            if !short {
                let rscContainer = try CompressedFileContainer(withDirectory: headlineFolder, encoding: .utf16LittleEndian)
                if rscContainer.files.count > 0 {
                    return try Self.parseRSCs(container: rscContainer)
                }
            }

            return nil
        } else {
            return nil
        }
    }

    public static func parseRSCs(container: CompressedFileContainer) throws -> HeadlineStore {
        var headlines = [Headline]()
        for file in container.files {
            let t = Tokenizer(input: file.text)
            try t.consume(expect: "<h1 id=\"")
            let id = t.consume(upUntil: "\"")
            var type = ""
            try t.ifConsume(expect: "\" type=\"w\" rank=\"", {
                type = "word"
            })
            try t.ifConsume(expect: "\" type=\"k\" rank=\"", {
                type = "kanji"
            })
            let rank = t.consume(upUntil: "\"")
            try t.consume(expect: "\">")
            var kana: String?
            try t.ifConsume(expect: "<kn>") {
                kana = t.consume(upUntil: "<")
                try t.consume(expect: "</kn>")
            }
            var spelling: String?
            try t.ifConsume(expect: "<sp>", {
                var s = ""
                try t.consume(expect: "<pr>")
                s += String(t.consume())
                try t.consume(expect: "</pr>")
                s += t.consume(upUntil: "<")
                try t.consume(expect: "<pr>")
                s += String(t.consume())
                try t.consume(expect: "</pr></sp>")
                spelling = s
            })
            var kanjis = [String]()

            func scan(v: inout String) throws {
                try t.ifConsume(expect: "<pr>", {
                    v += String(t.consume())
                    try t.consume(expect: "</pr>")
                })

                try t.ifConsume(expect: "<span", {
                    t.consume(upUntil: ">")
                    v += t.consume(upUntil: "<")
                    try t.consume(expect: "</span>")
                })

                try t.ifConsume(expect: "<ggk", {
                    t.consume(upUntil: ">")
                    t.consume()
                    try scan(v: &v)
                    v += t.consume(upUntil: "<")
                    try t.consume(expect: "</ggk>")
                })
            }

            try t.ifConsume(expect: "<hy1>", {
                var kanji = ""
                while !t.hasPrefix("</hy1>") {
                    kanji += t.consume(upUntil: "<")
                    try scan(v: &kanji)
                    kanji += t.consume(upUntil: "<")
                }
                try t.consume(expect: "</hy1>")
                kanjis.append(kanji)
            })
            try t.ifConsume(expect: "<hy2>", {
                var kanji = ""
                while !t.hasPrefix("</hy2>") {
                    kanji += t.consume(upUntil: "<")
                    try scan(v: &kanji)
                    kanji += t.consume(upUntil: "<")
                }
                try t.consume(expect: "</hy2>")
                kanjis.append(kanji)
            })
            try t.ifConsume(expect: "<ky>", {
                var kanji = ""
                while !t.hasPrefix("</ky>") {
                    kanji += t.consume(upUntil: "<")
                    try scan(v: &kanji)
                    kanji += t.consume(upUntil: "<")
                }
                try t.consume(expect: "</ky>")
                kanjis.append(kanji)
            })
            try t.ifConsume(expect: "<cl>", {
                t.consume(upUntil: "</cl>")
                try t.consume(expect: "</cl>")
            })
            try t.consume(expect: "</h1>")
            if let kana = kana, let integerID = Int(id) {
                let headline = Headline(index: UInt(integerID), subindex: 0, text: "\(kana)\(spelling ?? "")\(kanjis.joined())")
                headlines.append(headline)
            } else {
                print(id, type, rank, kana, spelling, kanjis)
            }
        }
        return .init(headlines: headlines)
    }

    public static func parse(tokenizer: DataTokenizer) throws -> HeadlineStore {
        try tokenizer.consumeInt32(expect: 0)
        try tokenizer.consumeInt32(expect: 2)
        let count = tokenizer.consumeInt32()
        let offset = tokenizer.consumeInt32()
        let secondSectionStart = tokenizer.consumeInt32()
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

