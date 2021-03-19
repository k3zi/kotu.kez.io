import Foundation

enum NeedlemanWunsch {

    enum Origin {
        case top
        case left
        case diagonal
    }

    enum Match {
        case indexAndValue(Int, String)
        case missing
    }

    static func align(input1 seq1: [Character], input2 seq2: [Character], match: Int = 5, substitution: Int = -2, gap: Int = -6) -> (output1: [Match], output2: [Match]) {
        var scores: [[Int]] = Array(repeating: Array(repeating: 0, count: seq1.count + 1), count: seq2.count + 1)
        var paths: [[[Origin]]] = Array(repeating: Array(repeating: [], count: seq1.count + 1), count: seq2.count + 1)

        for j in 1...seq1.count {
            scores[0][j] = scores[0][j - 1] + gap
            paths[0][j] = [.left]
        }
        for i in 1...seq2.count {
            scores[i][0] = scores[i - 1][0] + gap
            paths[i][0] = [.top]
        }

        for i in 1...seq2.count {
            for j in 1...seq1.count {
                let fromTop = scores[i - 1][j] + gap
                let fromLeft = scores[i][j - 1] + gap
                let fromDiagonal = scores[i - 1][j - 1] + (seq1[j - 1] == seq2[i - 1] ? match : substitution)
                let fromMax = max(fromTop, fromLeft, fromDiagonal)

                scores[i][j] = fromMax

                if fromDiagonal == fromMax { paths[i][j].append(.diagonal) }
                if fromTop == fromMax { paths[i][j].append(.top) }
                if fromLeft == fromMax { paths[i][j].append(.left) }
            }
        }

        var output1 = [Match]()
        var output2 = [Match]()

        var i = seq2.count
        var j = seq1.count

        while i != 0 && j != 0 {
            switch paths[i][j].first! {
            case .diagonal:
                output1.insert(.indexAndValue(j - 1, String(seq1[j - 1])), at: .zero)
                output2.insert(.indexAndValue(i - 1, String(seq2[i - 1])), at: .zero)
                i -= 1
                j -= 1
            case .top:
                output1.insert(.missing, at: 0)
                output2.insert(.indexAndValue(i - 1, String(seq2[i - 1])), at: .zero)
                i -= 1
            case .left:
                output1.insert(.indexAndValue(j - 1, String(seq1[j - 1])), at: .zero)
                output2.insert(.missing, at: .zero)
                j -= 1
            }
        }

        return (output1, output2)
    }
}
