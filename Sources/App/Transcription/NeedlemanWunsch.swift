import Foundation

enum NeedlemanWunsch {

    enum Origin {
        case top
        case left
        case diagonal
    }

    enum Match {
        case indexAndValue(Int, Character)
        case missing
    }

    enum Error: Swift.Error {
        case couldNotFindOverlap
    }

    static func align(input1 seq1: [Character], input2 seq2: [Character], match: Int = 5, substitution: Int = -3, gap: Int = -2, offset1: Int = 0, offset2: Int = 0) throws -> (output1: [Match], output2: [Match]) {
        let m = min(seq1.count, seq2.count)
        if m < 20000 {
            return partialAlign(input1: seq1, input2: seq2, match: match, substitution: substitution, gap: gap, offset1: offset1, offset2: offset2)
        }

        let seq1Halves = seq1.split()
        let seq2Halves = seq2.split()

        let overlap = m / 8

        let left = try align(
            input1: seq1Halves[0] + seq1Halves[1].prefix(upTo: overlap),
            input2: seq2Halves[0] + seq2Halves[1].prefix(upTo: overlap),
            match: match, substitution: substitution, gap: gap,
            offset1: offset1,
            offset2: offset2
        )
        let right = try align(
            input1: seq1Halves[0].suffix(overlap) + seq1Halves[1],
            input2: seq2Halves[0].suffix(overlap) + seq2Halves[1],
            match: match, substitution: substitution, gap: gap,
            offset1: offset1 + seq1Halves[0].count - overlap,
            offset2: offset2 + seq2Halves[0].count - overlap
        )
        let middle = try align(
            input1: seq1Halves[0].suffix(overlap) + seq1Halves[1].prefix(upTo: overlap),
            input2: seq2Halves[0].suffix(overlap) + seq2Halves[1].prefix(upTo: overlap),
            match: match, substitution: substitution, gap: gap,
            offset1: offset1 + seq1Halves[0].count - overlap,
            offset2: offset2 + seq2Halves[0].count - overlap
        )
        let zipped = Array(zip(middle.output1, middle.output2))
        let firstOverlapOptionalIndex = zipped.firstSeries(length: 5, where: {
            if case let .indexAndValue(_, first) = $0.0, case let .indexAndValue(_, second) = $0.1 {
                return first == second
            }
            return false
        })
        let lastOverlapOptionalIndex = zipped.lastSeries(length: 5, where: {
            if case let .indexAndValue(_, first) = $0.0, case let .indexAndValue(_, second) = $0.1 {
                return first == second
            }
            return false
        })
        guard let firstOverlapIndex = firstOverlapOptionalIndex, let lastOverlapIndex = lastOverlapOptionalIndex else {
            throw Error.couldNotFindOverlap
        }
        let firstOverlapOptional = middle.output1[firstOverlapIndex]
        let lastOverlapOptional = middle.output1[lastOverlapIndex]

        guard case let .indexAndValue(seq1OverlapFirstIndex, _) = firstOverlapOptional else {
            throw Error.couldNotFindOverlap
        }

        guard case let .indexAndValue(seq1OverlapLastIndex, _) = lastOverlapOptional else {
            throw Error.couldNotFindOverlap
        }

        let matchingLeftIndexOptional = left.output1.lastIndex(where: {
            if case let .indexAndValue(index, _) = $0, index == seq1OverlapFirstIndex {
                return true
            }
            return false
        })

        let matchingRightIndexOptional = right.output1.firstIndex(where: {
            if case let .indexAndValue(index, _) = $0, index == seq1OverlapLastIndex {
                return true
            }
            return false
        })

        guard let leftIndex = matchingLeftIndexOptional, let rightIndex = matchingRightIndexOptional else {
            throw Error.couldNotFindOverlap
        }

        let output1 = Array(left.output1[..<leftIndex]) + Array(middle.output1[firstOverlapIndex...lastOverlapIndex]) + Array(right.output1[rightIndex...])
        let output2 = Array(left.output2[..<leftIndex]) + Array(middle.output2[firstOverlapIndex...lastOverlapIndex]) + Array(right.output2[rightIndex...])
        return (output1, output2)
    }

    static func partialAlign(input1 seq1: [Character], input2 seq2: [Character], match: Int = 5, substitution: Int = -3, gap: Int = -2, offset1: Int = 0, offset2: Int = 0) -> (output1: [Match], output2: [Match]) {
        var scores: [[Int]] = Array(repeating: Array(repeating: 0, count: seq1.count + 1), count: seq2.count + 1)
        var paths: [[[Origin]]] = Array(repeating: Array(repeating: [], count: seq1.count + 1), count: seq2.count + 1)

        for j in 1...seq1.count {
            scores[0][j] = scores[0][j - 1] &+ gap
            paths[0][j] = [.left]
        }
        for i in 1...seq2.count {
            scores[i][0] = scores[i - 1][0] &+ gap
            paths[i][0] = [.top]
        }

        for i in 1...seq2.count {
            for j in 1...seq1.count {
                let fromTop = scores[i &- 1][j] &+ gap
                let fromLeft = scores[i][j &- 1] &+ gap
                let fromDiagonal = scores[i &- 1][j &- 1] &+ (seq1[j &- 1] == seq2[i &- 1] ? match : substitution)
                let fromMax = max(fromTop, fromLeft, fromDiagonal)

                scores[i][j] = fromMax

                if fromDiagonal == fromMax { paths[i][j].append(.diagonal) }
                if fromTop == fromMax { paths[i][j].append(.top) }
                if fromLeft == fromMax { paths[i][j].append(.left) }
            }
        }

        var i = seq2.count
        var j = seq1.count
        var output1 = [Match]()
        var output2 = [Match]()

        let m = max(i, j)
        output1.reserveCapacity(m)
        output2.reserveCapacity(m)

        while i != 0 && j != 0 {
            switch paths[i][j].first! {
            case .diagonal:
                output1.insert(.indexAndValue(j - 1 + offset1, seq1[j &- 1]), at: .zero)
                output2.insert(.indexAndValue(i - 1 + offset2, seq2[i &- 1]), at: .zero)
                i &-= 1
                j &-= 1
            case .top:
                output1.insert(.missing, at: 0)
                output2.insert(.indexAndValue(i &- 1 &+ offset2, seq2[i &- 1]), at: .zero)
                i &-= 1
            case .left:
                output1.insert(.indexAndValue(j &- 1 &+ offset1, seq1[j &- 1]), at: .zero)
                output2.insert(.missing, at: .zero)
                j &-= 1
            }
        }

        return (output1, output2)
    }
}
