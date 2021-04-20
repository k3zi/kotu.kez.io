import Foundation

extension Sequence {
    func splitKeepingSeparator(whereSeparator isSeparator: (Self.Element) throws -> Bool) rethrows -> [ArraySlice<Self.Element>] {
        return try Array(self).splitKeepingSeparator(whereSeparator: isSeparator)
    }

    func splitSeparator(by decision: (Self.Element) throws -> SeparatorDecision) rethrows -> [ArraySlice<Self.Element>] {
        return try Array(self).splitSeparator(by: decision)
    }
}
