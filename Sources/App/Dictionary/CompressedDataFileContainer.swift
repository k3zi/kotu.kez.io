import Foundation

public struct CompressedDataFileContainer {

    public init(withDirectory directoryURL: URL, encoding: String.Encoding = .utf8) throws {
        let fileManager = FileManager.default
        let indexFileURL = directoryURL.appendingPathComponent("index.nidx")
        let indexTokenizer = try DataTokenizer(data: Data(contentsOf: indexFileURL))
        let index = try Index.parse(tokenizer: indexTokenizer, encoding: encoding)
        let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        let collections: [Data] = fileURLs
            .filter { $0.pathExtension == "nrsc" }
            .sorted(by: { $0.path < $1.path })
            .concurrentMap {
                try! Data(contentsOf: $0)
            }
        files = index.elements.concurrentMap { element in
            let data = collections[element.containerIndex][element.dataOffset..<(element.dataOffset + element.dataSize)]
            return .init(filename: element.filename, data: (try? data.gunzipped()) ?? data)
        }
    }

    public let files: [Self.File]

}

extension CompressedDataFileContainer {

    public struct Index {

        public struct Element {
            public let containerIndex: Int
            public let filename: String
            public let dataOffset: Int
            public let dataSize: Int
        }

        public static func parse(tokenizer: DataTokenizer, encoding: String.Encoding = .utf8) throws -> Self {
            var elements = [Element]()
            try tokenizer.consumeInt32(expect: 0)
            let count = tokenizer.consumeInt32() // count of entries
            for _ in 0..<count  {
                tokenizer.consumeInt16() // number of bytes for container index??
                let containerIndex = Int(tokenizer.consumeInt16())
                let filenameOffset = Int(tokenizer.consumeInt32())
                let dataOffset = Int(tokenizer.consumeInt32())
                let dataSize = Int(tokenizer.consumeInt32())

                let filename = tokenizer.consume(from: filenameOffset, until: { $0 == .zero })
                elements.append(.init(containerIndex: containerIndex, filename: String(bytes: filename, encoding: encoding)!, dataOffset: dataOffset, dataSize: dataSize))
            }
            return .init(elements: elements)
        }

        public let elements: [Element]

    }

    public struct File {
        public let filename: String
        public let data: Data
    }

}

