import Foundation

extension Sequence {
    func splitKeepingSeparator(whereSeparator isSeparator: (Self.Element) throws -> Bool) rethrows -> [ArraySlice<Self.Element>] {
        return try Array(self).splitKeepingSeparator(whereSeparator: isSeparator)
    }
}