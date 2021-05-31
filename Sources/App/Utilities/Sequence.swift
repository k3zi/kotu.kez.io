import Foundation

extension Sequence {

    func splitKeepingSeparator(whereSeparator isSeparator: (Self.Element) throws -> Bool) rethrows -> [ArraySlice<Self.Element>] {
        return try Array(self).splitKeepingSeparator(whereSeparator: isSeparator)
    }

    func splitSeparator(by decision: (Self.Element) throws -> SeparatorDecision) rethrows -> [ArraySlice<Self.Element>] {
        return try Array(self).splitSeparator(by: decision)
    }

    /// Returns `self.map(transform)`, computed in parallel.
    ///
    /// - Requires: `transform` is safe to call from multiple threads.
    func concurrentMap<B>(batchSize: Int = 4096, _ transform: (Element) -> B) -> [B] {
        ArraySlice(self).concurrentMap(batchSize: batchSize, transform)
    }

}
