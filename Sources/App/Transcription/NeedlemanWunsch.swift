import Foundation

extension Array {
    subscript<T>(js index: Index) -> T where Element == T? {
        get { self[index]! }
        set { self[index] = newValue }
    }
}

enum NeedlemanWunsch {

    enum Match<T>: Equatable where T: Equatable {
        case indexAndValue(Int, T)
        case missing
    }

//    static func align(input1 seq1: [Character], input2 seq2: [Character], match: Int = 10, substitution: Int = -3, gap: Int = -2, offset1: Int = 0, offset2: Int = 0) throws -> (output1: [Match], output2: [Match]) {
//        let m = min(seq1.count, seq2.count)
//        if m < 20000 {
//            return partialAlign(input1: seq1, input2: seq2, match: match, substitution: substitution, gap: gap, offset1: offset1, offset2: offset2)
//        }
//
//        let seq1Halves = seq1.split()
//        let seq2Halves = seq2.split()
//
//        let overlap = m / 8
//
//        let left = try align(
//            input1: seq1Halves[0] + seq1Halves[1].prefix(upTo: overlap),
//            input2: seq2Halves[0] + seq2Halves[1].prefix(upTo: overlap),
//            match: match, substitution: substitution, gap: gap,
//            offset1: offset1,
//            offset2: offset2
//        )
//        let right = try align(
//            input1: seq1Halves[0].suffix(overlap) + seq1Halves[1],
//            input2: seq2Halves[0].suffix(overlap) + seq2Halves[1],
//            match: match, substitution: substitution, gap: gap,
//            offset1: offset1 + seq1Halves[0].count - overlap,
//            offset2: offset2 + seq2Halves[0].count - overlap
//        )
//        let middle = try align(
//            input1: seq1Halves[0].suffix(overlap) + seq1Halves[1].prefix(upTo: overlap),
//            input2: seq2Halves[0].suffix(overlap) + seq2Halves[1].prefix(upTo: overlap),
//            match: match, substitution: substitution, gap: gap,
//            offset1: offset1 + seq1Halves[0].count - overlap,
//            offset2: offset2 + seq2Halves[0].count - overlap
//        )
//        let zipped = Array(zip(middle.output1, middle.output2))
//        let firstOverlapOptionalIndex = zipped.firstSeries(length: 10, where: {
//            if case let .indexAndValue(_, first) = $0.0, case let .indexAndValue(_, second) = $0.1 {
//                return first == second
//            }
//            return false
//        })
//        let lastOverlapOptionalIndex = zipped.lastSeries(length: 10, where: {
//            if case let .indexAndValue(_, first) = $0.0, case let .indexAndValue(_, second) = $0.1 {
//                return first == second
//            }
//            return false
//        })
//        guard let firstOverlapIndex = firstOverlapOptionalIndex, let lastOverlapIndex = lastOverlapOptionalIndex else {
//            throw Error.couldNotFindOverlap
//        }
//        let firstOverlapOptional = middle.output1[firstOverlapIndex]
//        let lastOverlapOptional = middle.output1[lastOverlapIndex]
//
//        guard case let .indexAndValue(seq1OverlapFirstIndex, _) = firstOverlapOptional else {
//            throw Error.couldNotFindOverlap
//        }
//
//        guard case let .indexAndValue(seq1OverlapLastIndex, _) = lastOverlapOptional else {
//            throw Error.couldNotFindOverlap
//        }
//
//        let matchingLeftIndexOptional = left.output1.lastIndex(where: {
//            if case let .indexAndValue(index, _) = $0, index == seq1OverlapFirstIndex {
//                return true
//            }
//            return false
//        })
//
//        let matchingRightIndexOptional = right.output1.firstIndex(where: {
//            if case let .indexAndValue(index, _) = $0, index == seq1OverlapLastIndex {
//                return true
//            }
//            return false
//        })
//
//        guard let leftIndex = matchingLeftIndexOptional, let rightIndex = matchingRightIndexOptional else {
//            throw Error.couldNotFindOverlap
//        }
//
//        let output1 = Array(left.output1[..<leftIndex]) + Array(middle.output1[firstOverlapIndex...lastOverlapIndex]) + Array(right.output1[rightIndex...])
//        let output2 = Array(left.output2[..<leftIndex]) + Array(middle.output2[firstOverlapIndex...lastOverlapIndex]) + Array(right.output2[rightIndex...])
//        return (output1, output2)
//    }

    static func compressAlign<T>(input1 seq1: [T], input2 seq2: [T], match: Int = 5, substitution: Int = -3, gap: Int = -2, offset1: Int = 0, offset2: Int = 0) -> (output1: [Match<T>], output2: [Match<T>]) where T: Hashable {
        let uniqueElements = Array(Set(seq1 + seq2))

        func convert<S>(matches: [Match<S>], mapping: [S: T]) -> [Match<T>] {
            matches.map {
                if case let .indexAndValue(i, v) = $0 {
                    return .indexAndValue(i, mapping[v]!)
                }

                return .missing
            }
        }

        if uniqueElements.count < UInt8.max {
            let mapping = Swift.Dictionary(uniqueKeysWithValues: uniqueElements.indices.map { (uniqueElements[$0], UInt8(exactly: $0)!) })
            let reverseMapping = Swift.Dictionary(uniqueKeysWithValues: uniqueElements.indices.map { (UInt8(exactly: $0)!, uniqueElements[$0]) })
            let output = align(input1: seq1.map { mapping[$0] }, input2: seq2.map { mapping[$0] }, match: match, substitution: substitution, gap: gap, offset1: offset1, offset2: offset2)
            return (output1: convert(matches: output.output1, mapping: reverseMapping), output2: convert(matches: output.output2, mapping: reverseMapping))
        } else if uniqueElements.count < UInt16.max {
            let mapping = Swift.Dictionary(uniqueKeysWithValues: uniqueElements.indices.map { (uniqueElements[$0], UInt16(exactly: $0)!) })
            let reverseMapping = Swift.Dictionary(uniqueKeysWithValues: uniqueElements.indices.map { (UInt16(exactly: $0)!, uniqueElements[$0]) })
            let output = align(input1: seq1.map { mapping[$0] }, input2: seq2.map { mapping[$0] }, match: match, substitution: substitution, gap: gap, offset1: offset1, offset2: offset2)
            return (output1: convert(matches: output.output1, mapping: reverseMapping), output2: convert(matches: output.output2, mapping: reverseMapping))
        } else if uniqueElements.count < UInt32.max {
            let mapping = Swift.Dictionary(uniqueKeysWithValues: uniqueElements.indices.map { (uniqueElements[$0], UInt32(exactly: $0)!) })
            let reverseMapping = Swift.Dictionary(uniqueKeysWithValues: uniqueElements.indices.map { (UInt32(exactly: $0)!, uniqueElements[$0]) })
            let output = align(input1: seq1.map { mapping[$0] }, input2: seq2.map { mapping[$0] }, match: match, substitution: substitution, gap: gap, offset1: offset1, offset2: offset2)
            return (output1: convert(matches: output.output1, mapping: reverseMapping), output2: convert(matches: output.output2, mapping: reverseMapping))
        } else {
            let mapping = Swift.Dictionary(uniqueKeysWithValues: uniqueElements.indices.map { (uniqueElements[$0], UInt64(exactly: $0)!) })
            let reverseMapping = Swift.Dictionary(uniqueKeysWithValues: uniqueElements.indices.map { (UInt64(exactly: $0)!, uniqueElements[$0]) })
            let output = align(input1: seq1.map { mapping[$0] }, input2: seq2.map { mapping[$0] }, match: match, substitution: substitution, gap: gap, offset1: offset1, offset2: offset2)
            return (output1: convert(matches: output.output1, mapping: reverseMapping), output2: convert(matches: output.output2, mapping: reverseMapping))
        }
    }

    static func align<T>(input1 seq1: [T], input2 seq2: [T], match: Int = 5, substitution: Int = -3, gap: Int = -2, offset1: Int = 0, offset2: Int = 0) -> (output1: [Match<T>], output2: [Match<T>]) where T: Equatable {
        let substitution = -substitution + match
        let gap = -gap + match
        var output1 = [Match<T>]()
        var output2 = [Match<T>]()
        let m = max(seq1.count, seq2.count)
        output1.reserveCapacity(m)
        output2.reserveCapacity(m)
        var fwd: [[Int?]] = [Array(repeating: nil, count: m), Array(repeating: nil, count: m)]
        var rev: [[Int?]] = [Array(repeating: nil, count: m), Array(repeating: nil, count: m)]

        func forwardAlg(p1: Int, p2: Int, q1: Int, q2: Int) {
            fwd[p1 % 2][js: q1] = 0
            for j in (q1 + 1)...q2 {
                fwd[p1 % 2][js: j] = fwd[p1 % 2][js: j - 1] + gap
            }

            for i in (p1 + 1)...p2 {
                fwd[i % 2][js: q1] = fwd[(i - 1) % 2][js: q1] + gap

                for j in (q1 + 1)...q2 {
                    var diag = fwd[(i - 1) % 2][js: j - 1]
                    if seq1[i - 1] != seq2[j - 1] {
                        diag += substitution
                    }

                    fwd[i % 2][js: j] = min(diag, min(fwd[(i - 1) % 2][js: j] + gap, fwd[i % 2][js: j - 1] + gap))
                }
            }
        }

        func reverseAlg(p1: Int, p2: Int, q1: Int, q2: Int) {
            rev[p2 % 2][js: q2] = 0
            for j in stride(from: q2 - 1, through: q1, by: -1) {
                rev[p2 % 2][js: j] = rev[p2 % 2][js: j + 1] + gap
            }

            for i in stride(from: p2 - 1, through: p1, by: -1) {
                rev[i % 2][js: q2] = rev[(i + 1) % 2][js: q2] + gap

                for j in stride(from: q2 - 1, through: q1, by: -1) {
                    var diag = rev[(i + 1) % 2][js: j + 1]
                    if seq1[i] != seq2[j] {
                        diag += substitution
                    }

                    rev[i % 2][js: j] = min(diag, min(rev[(i + 1) % 2][js: j] + gap, rev[i % 2][js: j + 1] + gap))
                }
            }
        }

        func align(p1: Int, p2: Int, q1: Int, q2: Int) {
            if p2 <= p1 {
                for i in q1..<q2 {
                    output1.append(.missing)
                    output2.append(.indexAndValue(i + offset2, seq2[i]))
                }
            } else if q2 <= q1 {
                for i in p1..<p2 {
                    output1.append(.indexAndValue(i + offset1, seq1[i]))
                    output2.append(.missing)
                }
            } else if p2 - 1 == p1 {
                let ch = seq1[p1]
                var memo = q1
                for i in (q1 + 1)..<q2 {
                    if seq2[i] == ch {
                        memo = i
                    }
                }

                for i in q1..<q2 {
                    if i == memo {
                        output1.append(.indexAndValue(p1 + offset1, ch))
                    } else {
                        output1.append(.missing)
                    }
                    output2.append(.indexAndValue(i + offset2, seq2[i]))
                }
            } else {
                let mid = (p1 + p2) / 2
                let queue1 = DispatchQueue(label: UUID().uuidString)
                let queue2 = DispatchQueue(label: UUID().uuidString)
                let group = DispatchGroup()
                queue1.async(group: group) {
                    forwardAlg(p1: p1, p2: mid, q1: q1, q2: q2)
                }
                queue2.async(group: group) {
                    reverseAlg(p1: mid, p2: p2, q1: q1, q2: q2)
                }
                group.wait()
                var s2mid = q1
                var best = Int.max

                for i in q1...q2 {
                    let sum = fwd[mid % 2][js: i] + rev[mid % 2][js: i]
                    if sum < best {
                        best = sum
                        s2mid = i
                    }
                }

                align(p1: p1, p2: mid, q1: q1, q2: s2mid)
                align(p1: mid, p2: p2, q1: s2mid, q2: q2)
            }
        }

        align(p1: 0, p2: seq1.count, q1: 0, q2: seq2.count)
        return (output1, output2)
    }

}
