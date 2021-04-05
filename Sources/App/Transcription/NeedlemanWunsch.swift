import Foundation

enum NeedlemanWunsch {

    enum Origin: UInt8 {
        /// XY | 1
        case diagonal = 0x1
        /// xY | 2
        case top = 0x2
        /// Xy | 3
        case left = 0x3
    }

    enum Match {
        case indexAndValue(Int, Character)
        case missing
    }

    struct Branch {
        let m: Int
        let x: Int
        let y: Int
    }

    enum Error: Swift.Error {
        case couldNotFindOverlap
    }

    typealias Alignment = Origin

    static func align(input1 seq1: [Character], input2 seq2: [Character], match: Int = 10, substitution: Int = -3, gap: Int = -2, offset1: Int = 0, offset2: Int = 0) throws -> (output1: [Match], output2: [Match]) {
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
        let firstOverlapOptionalIndex = zipped.firstSeries(length: 10, where: {
            if case let .indexAndValue(_, first) = $0.0, case let .indexAndValue(_, second) = $0.1 {
                return first == second
            }
            return false
        })
        let lastOverlapOptionalIndex = zipped.lastSeries(length: 10, where: {
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

    static func partialAlign(input1 seq1: [Character], input2 seq2: [Character], match: Int = 5, substitution mismatch: Int = -3, gap: Int = -2, gapStart: Int = 0, offset1: Int = 0, offset2: Int = 0) -> (output1: [Match], output2: [Match]) {
        let X = seq1
        let Y = seq2
        let XY = Alignment.diagonal.rawValue
        let xY = Alignment.top.rawValue
        let Xy = Alignment.left.rawValue

        let g0 = seq1.count - seq2.count
        var gM = g0 == .zero ? 0 : gapStart
        let m0: Int
        if g0 < 0 {
            gM += -g0 * gap
            m0 = X.count
        } else {
            gM += g0 * gap
            m0 = Y.count
        }

        let gm = gM + m0 * mismatch
        gM += m0 * match

        var alignments: [[Alignment?]] = Array(repeating: Array(repeating: nil, count: Y.count + 1), count: X.count + 1)
        var scores: [[Int]] = Array(repeating: Array(repeating: gm, count: Y.count + 1), count: X.count + 1)
        scores[0][0] = .zero

        var Mi = gM - gm + 1
        var mi = Mi

        var queue = [[Branch]?](repeating: nil, count: Mi)
        queue[Mi - 1] = [Branch(m: 1, x: 1, y: 1)]

        func enqueue(M: Int, m: Int, x: Int, y: Int, alignment: UInt8) {
            var x = x
            var y = y

            if alignment & 1 != .zero {
                x = -x
            }

            if alignment & 2 != .zero {
                y = -y
            }

            let branch = Branch(m: m, x: x, y: y)
            let i = M - gm + 1
            if i > Mi {
                Mi = i
            }

            if i < mi || mi == 0 {
                mi = i
            }

            if queue[i - 1] == nil {
                queue[i - 1] = [branch]
            } else {
                var j = 1
                while j <= queue[i - 1]!.count && queue[i - 1]![j - 1].m <= m {
                    j += 1
                }
                queue[i - 1]!.insert(branch, at: j - 1)
            }
        }

        func dequeue() -> (x: Int, y: Int, alignment: UInt8) {
            let last = queue[Mi - 1]!.removeLast()
            var x = last.x
            var y = last.y
            var alignment: UInt8 = 0x0

            if x < 0 {
                x = -x
                alignment |= 1
            }

            if y < 0 {
                y = -y
                alignment |= 2
            }

            while queue[Mi - 1] == nil || queue[Mi - 1]!.isEmpty {
                if Mi == mi {
                    Mi = 0
                    mi = 0
                    break
                }
                Mi -= 1
            }

            return (x: x, y: y, alignment: alignment)
        }

        var ox = seq1.count + 1
        var oy = seq2.count + 1
        while Mi - 1 + gm > scores[ox - 1][oy - 1] {
            var (x, y, alignment) = dequeue()
            var didPrune = false
            prune: while x <= X.count && y <= Y.count {
                var sorted: UInt8 = 0 // XY = 1, xY = 2
                let xyScore = scores[x - 1][y - 1]
                let score = [
                    0,
                    xyScore + (X[x - 1] == Y[y - 1] ? match : mismatch),
                    xyScore + gap + (alignment == xY ? 0 : gapStart),
                    xyScore + gap + (alignment == Xy ? 0 : gapStart)
                ]
                var M = Array(repeating: 0, count: 4)
                var m = Array(repeating: 0, count: 4)

                if score[Int(XY)] > scores[x][y] {
                    M[Int(XY)] = score[Int(XY)]
                    scores[x][y] = M[Int(XY)]

                    let rx = X.count - x
                    let ry = Y.count - y
                    var g = rx - ry
                    var r = ry
                    if g != .zero {
                        M[Int(XY)] += gapStart

                        if g < 0 {
                            g = -g
                            r = rx
                        }
                    }

                    M[Int(XY)] += g * gap
                    m[Int(XY)] = M[Int(XY)] + r * mismatch
                    M[Int(XY)] += r * match

                    if M[Int(XY)] > scores[ox - 1][oy - 1] {
                        sorted = XY
                    }
                }

                if score[Int(xY)] > scores[x - 1][y] {
                    M[Int(xY)] = score[Int(xY)]
                    scores[x - 1][y] = M[Int(xY)]
                    let rx = X.count + 1 - x
                    let ry = Y.count - y
                    var g = ry - rx
                    var r = rx
                    if g < 0 {
                        g = -g
                        r = ry
                        M[Int(xY)] += gapStart
                    }

                    M[Int(xY)] += g * gap
                    m[Int(xY)] = M[Int(xY)] + r * mismatch
                    M[Int(xY)] += r * match

                    if M[Int(xY)] > scores[ox - 1][oy - 1] {
                        if sorted == 0 || (M[Int(xY)] >= M[Int(XY)] && (M[Int(xY)] > M[Int(XY)] || m[Int(xY)] > m[Int(XY)])) {
                            sorted <<= 2
                            sorted |= xY
                        } else {
                            sorted |= xY << 2
                        }
                    }
                }

                if score[Int(Xy)] > scores[x][y - 1] {
                    M[Int(Xy)] = score[Int(Xy)]
                    scores[x][y - 1] = M[Int(Xy)]
                    let rx = X.count - x
                    let ry = Y.count + 1 - y
                    var g = rx - ry
                    var r = ry

                    if g < 0 {
                        g = -g
                        r = rx
                        M[Int(Xy)] += gapStart
                    }

                    M[Int(Xy)] += g * gap
                    m[Int(Xy)] = M[Int(Xy)] + r * mismatch
                    M[Int(Xy)] += r * match

                    if M[Int(Xy)] > scores[ox - 1][oy - 1] {
                        var t = sorted >> 2
                        if t == 0 || (M[Int(Xy)] >= M[Int(t)] && (M[Int(Xy)] > M[Int(t)] || m[Int(Xy)] > m[Int(t)])) {
                            let u = sorted & 0b11
                            if u == 0 || (M[Int(Xy)] >= M[Int(u)] && (M[Int(Xy)] > M[Int(u)] || m[Int(Xy)] > m[Int(u)])) {
                                sorted <<= 2
                                sorted |= Xy
                            } else {
                                sorted = u
                                t = t << 4 | Xy << 2
                                sorted |= t
                            }
                        } else {
                            sorted |= Xy << 4
                        }
                    }
                }

                let alignment = sorted & 0b11
                if alignment == .zero {
                    didPrune = true
                    break prune
                }
                let a = (sorted & 0b1100) >> 2
                if a != 0 && M[Int(a)] > m[Int(alignment)] {
                    enqueue(M: M[Int(a)], m: m[Int(a)], x: a == xY ? x : (x + 1), y: a == Xy ? y : (y + 1), alignment: a)
                    let b = sorted >> 4
                    if b != 0 && M[Int(b)] > m[Int(a)] {
                        enqueue(M: M[Int(b)], m: m[Int(b)], x: b == xY ? x : (x + 1), y: b == Xy ? y : (y + 1), alignment: b)
                    }
                }
                x = alignment == xY ? x : (x + 1)
                y = alignment == Xy ? y : (y + 1)
                alignments[x - 1][y - 1] = Alignment(rawValue: alignment)!
            }
            if !didPrune {
                ox = x
                oy = y
            }
        }

        var i = ox
        var j = oy
        var output1 = [Match]()
        var output2 = [Match]()
        let m = max(i, j)
        output1.reserveCapacity(m)
        output2.reserveCapacity(m)

        // Backtrace the best score (from the bottom right of the matrix)
        while i != 1 || j != 1 {
            switch alignments[i - 1][j - 1] {
            case .diagonal, nil:
                i &-= 1
                j &-= 1
                output1.insert(.indexAndValue(i - 1 + offset2, seq1[i - 1]), at: .zero)
                output2.insert(.indexAndValue(j - 1 + offset1, seq2[j - 1]), at: .zero)
            case .left:
                i -= 1
                output1.insert(.indexAndValue(i - 1 + offset1, seq1[i - 1]), at: .zero)
                output2.insert(.missing, at: .zero)
            case .top:
                j -= 1
                output1.insert(.missing, at: 0)
                output2.insert(.indexAndValue(j - 1 + offset2, seq2[j - 1]), at: .zero)
            }
        }

        return (output1, output2)
    }

}
