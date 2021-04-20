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

enum SeparatorDecision {
    case keepLeft
    case keepRight
    case remove
    case notSeparator
}

extension Collection where Self.Index: Strideable, Self.Index.Stride: SignedInteger {
    func splitSeparator(by decision: (Self.Element) throws -> SeparatorDecision) rethrows -> [Self.SubSequence] {
        var sequences = [Self.SubSequence]()
        var startIndex = self.startIndex
        for index in self.startIndex..<endIndex {
            switch try decision(self[index]) {
            case .keepLeft:
                sequences.append(self[startIndex...index])
                startIndex = index.advanced(by: 1)
            case .keepRight:
                if index > startIndex {
                    sequences.append(self[startIndex..<index])
                }
                startIndex = index
            case .remove:
                if index > startIndex {
                    sequences.append(self[startIndex..<index])
                }
                startIndex = index.advanced(by: 1)
            case .notSeparator:
                if endIndex == index.advanced(by: 1) {
                    sequences.append(self[startIndex...index])
                }
            }
        }

        return sequences
    }
}
