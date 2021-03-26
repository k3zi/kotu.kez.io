import Foundation

extension Collection where Self.Index: Strideable, Self.Index.Stride: SignedInteger {
    func splitKeepingSeparator(whereSeparator isSeparator: (Self.Element) throws -> Bool) rethrows -> [Self.SubSequence] {
        var sequences = [Self.SubSequence]()
        var startIndex = self.startIndex
        for index in self.startIndex..<self.endIndex {
            if try isSeparator(self[index]) || self.endIndex == index.advanced(by: 1) {
                sequences.append(self[startIndex...index])
                startIndex = index.advanced(by: 1)
            }
        }
        
        return sequences
    }
}
