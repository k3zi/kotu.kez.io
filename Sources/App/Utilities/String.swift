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

}
