import Foundation

public struct CompressedFileContainer {

    public init(withDirectory directoryURL: URL, encoding: String.Encoding = .utf8) throws {
        let fileManager = FileManager.default
        let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        let collections: [Self.Collection] = try fileURLs
            .filter { $0.pathExtension == "rsc" }
            .sorted(by: { $0.path < $1.path })
            .map {
                return try Collection.parse(tokenizer: DataTokenizer(data: Data(contentsOf: $0)), encoding: encoding)
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

        public static func parse(tokenizer: DataTokenizer, encoding: String.Encoding = .utf8) throws -> Self {
            var files = [File]()
            while !tokenizer.reachedEnd {
                tokenizer.consumeUntil(nextByteGroupOf: 4)
                if tokenizer.reachedEnd {
                    break
                }
                let size = tokenizer.consumeInt32()
                let dataArray = tokenizer.dataConsuming(times: Int(size))
                let data = Data(dataArray)
                
                let decompressedData: Data
                do {
                    decompressedData = try data.gunzipped()
                } catch {
                    if let string = String(data: data, encoding: encoding) {
                        files.append(File(text: string))
                        continue
                    } else {
                        throw error
                    }
                }

                let partTokenizer = DataTokenizer(data: decompressedData)
                while !partTokenizer.reachedEnd {
                    let size = partTokenizer.consumeInt32()
                    let data = partTokenizer.dataConsuming(times: Int(size))
                    let string = String(data: data, encoding: encoding)!
                    files.append(File(text: string))
                    partTokenizer.consumeUntil(nextByteGroupOf: 4)
                }

                tokenizer.consumeUntil(nextByteGroupOf: 4)
            }
            return .init(files: files)
        }

        public let files: [File]

    }

}

