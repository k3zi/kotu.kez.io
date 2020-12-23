import Foundation

public struct CompressedFileContainer {

    public init(withDirectory directoryURL: URL) throws {
        let fileManager = FileManager.default
        let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        let collections: [Self.Collection] = try fileURLs
            .filter { $0.pathExtension == "rsc" }
            .sorted(by: { $0.path < $1.path })
            .map {
                print($0.path)
                return try Collection.parse(tokenizer: DataTokenizer(data: Data(contentsOf: $0)))
            }
        files = collections.flatMap { $0.files }
    }

    public let files: [Self.Collection.File]

}

extension CompressedFileContainer {

    public struct Collection {

        public struct File {
            public let text: String
        }

        public static func parse(tokenizer: DataTokenizer) throws -> Self {
            var files = [File]()
            while !tokenizer.reachedEnd {
                let size = tokenizer.consumeInt32()
                let dataArray = tokenizer.dataConsuming(times: Int(size))
                let data = Data(dataArray)
                let decompressedData = try data.gunzipped()

                let partTokenizer = DataTokenizer(data: decompressedData)
                while !partTokenizer.reachedEnd {
                    let here = partTokenizer.currentOffset
                    let size = partTokenizer.consumeInt32()
                    let data = partTokenizer.dataConsuming(times: Int(size))
                    let string = String(data: data, encoding: .utf8)!
                    files.append(File(text: string))
                    partTokenizer.consumeUntil(nextByteGroupOf: 4)
                }

                tokenizer.consumeUntil(nextByteGroupOf: 4)
            }
            print("finished \(files.count) files")
            print("endOffset: \(tokenizer.currentOffset)")
            return .init(files: files)
        }

        public let files: [File]

    }

}

