import Foundation

// from: https://gist.github.com/dabrahams/ea5495b4cccc2970cd56e8cfc72ca761
extension RandomAccessCollection {

    /// Returns `self.map(transform)`, computed in parallel.
    ///
    /// - Requires: `transform` is safe to call from multiple threads.
    func concurrentMap<B>(batchSize: Int = 4096, _ transform: (Element) -> B) -> [B] {
        let n = self.count
        let batchCount = (n + batchSize - 1) / batchSize
        if batchCount < 2 { return self.map(transform) }

        return Array(unsafeUninitializedCapacity: n) {
            uninitializedMemory, resultCount in
            resultCount = n
            let baseAddress = uninitializedMemory.baseAddress!

            DispatchQueue.concurrentPerform(iterations: batchCount) { b in
                let startOffset = b * n / batchCount
                let endOffset = (b + 1) * n / batchCount
                var sourceIndex = index(self.startIndex, offsetBy: startOffset)
                for p in baseAddress+startOffset..<baseAddress+endOffset {
                    p.initialize(to: transform(self[sourceIndex]))
                    formIndex(after: &sourceIndex)
                }
            }
        }
    }
}
