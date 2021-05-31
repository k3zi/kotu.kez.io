import Foundation


extension String {

    func editDistance(to target: String) -> Int {
        let rows = self.count
        let columns = target.count

        if rows <= 0 || columns <= 0 {
            return max(rows, columns)
        }

        var matrix = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)

        for row in 1...rows {
            matrix[row][0] = row
        }
        for column in 1...columns {
            matrix[0][column] = column
        }

        for row in 1...rows {
            for column in 1...columns {
                let source = self[self.index(self.startIndex, offsetBy: row - 1)]
                let target = target[target.index(target.startIndex, offsetBy: column - 1)]
                let cost = source == target ? 0 : 1

                matrix[row][column] = Swift.min(
                    matrix[row - 1][column] + 1,
                    matrix[row][column - 1] + 1,
                    matrix[row - 1][column - 1] + cost
                )
            }
        }

        return matrix.last!.last!
    }

    func minimalPair(with target: String) -> SyllabaryMinimalPair.Kind {
        if count == target.count && moraCount == target.moraCount {
            let differentPairs = zip(self, target).filter { $0.0 != $0.1 }
            guard differentPairs.count == 1, let differentPair = differentPairs.first else {
                return .none
            }

            struct BiCharacterMinimalPair {
                let first: Character
                let second: Character
                let kind: SyllabaryMinimalPair.Kind
            }

            let minimalPairs: [BiCharacterMinimalPair] = [
                BiCharacterMinimalPair(first: "ツ", second: "ス", kind: .tsuContrastSu),
                BiCharacterMinimalPair(first: "ド", second: "ロ", kind: .doContrastRo),
                BiCharacterMinimalPair(first: "ダ", second: "ラ", kind: .daContrastRa),
                BiCharacterMinimalPair(first: "デ", second: "ス", kind: .deContrastRe),
                BiCharacterMinimalPair(first: "ギ", second: "ニ", kind: .giContrastNi),
                BiCharacterMinimalPair(first: "ゲ", second: "ネ", kind: .geContrastNe)
            ]
            for minimalPair in minimalPairs {
                if Set([minimalPair.first, minimalPair.second]).intersection([differentPair.0, differentPair.1]).count == 2 {
                    return minimalPair.kind
                }
            }

            return .none
        }

        guard abs(moraCount - target.moraCount) == 1 else {
            return .none
        }

        let difference = self.difference(from: target)
        guard (difference.insertions.count == 1 && difference.removals.count == 0) || ((difference.insertions.count == 0 && difference.removals.count == 1)), let singularDifference = difference.insertions.first ?? difference.removals.first else {
            return .none
        }

        struct MonoCharacterMinimalPair {
            let first: Character
            let kind: SyllabaryMinimalPair.Kind
        }

        let possibleDifferences: [MonoCharacterMinimalPair] = [
            .init(first: "ー", kind: .shortContrastLongVowel),
            .init(first: "ッ", kind: .shortContrastLongConsonant)
        ]

        switch singularDifference {
        case let .insert(_, element, _), let .remove(_, element, _):
            return possibleDifferences.first { $0.first == element }?.kind ?? .none
        }
    }

}
