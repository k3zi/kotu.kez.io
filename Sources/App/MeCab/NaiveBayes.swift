import Foundation

extension Array where Element == Double {

    func mean() -> Double {
        return reduce(0, +) / Double(count)
    }

    func standardDeviation() -> Double {
        let calculatedMean = mean()

        let sum = reduce(0.0) { (previous, next) in
            return previous + pow(next - calculatedMean, 2)
        }

        return sqrt(sum / Double(count - 1))
    }

}

extension Array where Element: Hashable {

    func uniques() -> Set<Element> {
        return Set(self)
    }

}

enum NBType {

    case gaussian
    case multinomial

    func calcLikelihood(variables: [Any], input: Any) -> Double? {

        switch self {
        case .gaussian:
            guard let input = input as? Double else {
                return nil
            }
            guard let mean = variables[0] as? Double else {
                return nil
            }
            guard let stDev = variables[1] as? Double else {
                return nil
            }

            let eulerPart = pow(M_E, -1 * pow(input - mean, 2) / (2 * pow(stDev, 2)))
            let distribution = eulerPart / sqrt(2 * .pi) / stDev

            return distribution
        case .multinomial:
            guard let variables = variables as? [(category: Int, probability: Double)] else {
                return nil
            }

            guard let input = input as? Int else {
                return nil
            }

            return variables.first { $0.category == input }?.probability
        }
    }

    func train(values: [Any]) -> [Any]? {

        switch self {
        case .gaussian:
            guard let values = values as? [Double] else {
                return nil
            }

            return [values.mean(), values.standardDeviation()]
        case .multinomial:
            guard let values = values as? [Int] else {
                return nil
            }

            let count = values.count
            let categoryProba = values.uniques().map { value -> (Int, Double) in
                return (value, Double(values.filter { $0 == value }.count) / Double(count))
            }
            return categoryProba
        }
    }
}

class NaiveBayes<T, C: Hashable> {

    var variables: [C: [(feature: Int, variables: [Any])]]
    var type: NBType

    var data: [[T]]
    var classes: [C]

    init(type: NBType, data: [[T]], classes: [C]) throws {
        self.type = type
        self.data = data
        self.classes = classes
        self.variables = [C: [(Int, [Any])]]()

        if case .gaussian = type, T.self != Double.self {
            throw "When using Gaussian NB you have to have continuous features (Double)"
        } else if case .multinomial = type, T.self != Int.self {
            throw "When using Multinomial NB you have to have categorical features (Int)"
        }
    }

    func train() throws -> Self {
        for c in classes.uniques() {
            variables[c] = [(Int, [Any])]()

            let classDependent = data.enumerated().filter { offset, _ in
                return classes[offset] == c
            }

            for feature in 0..<data[0].count {
                let featureDependent = classDependent.map { $0.element[feature] }

                guard let trained = type.train(values: featureDependent) else {
                    throw "Critical! Data could not be casted even though it was checked at init"
                }

                variables[c]?.append((feature, trained))
            }
        }

        return self
    }

    func classify(with input: [T]) -> C? {
        let likelihoods = classifyProba(with: input).max { (first, second) -> Bool in
            return first.1 < second.1
        }

        guard let c = likelihoods?.0 else {
            return nil
        }

        return c
    }

    func classifyProba(with input: [T]) -> [(C, Double)] {

        var probaClass = [C: Double]()
        let amount = classes.count

        classes.forEach { c in
            let individual = classes.filter { $0 == c }.count
            probaClass[c] = Double(individual) / Double(amount)
        }

        let classesAndFeatures = variables.map { (`class`, value) -> (C, [Double]) in
            let distribution = value.map { (feature, variables) -> Double in
                return type.calcLikelihood(variables: variables, input: input[feature]) ?? 0.0
            }
            return (`class`, distribution)
        }

        let likelihoods = classesAndFeatures.map { (`class`, distribution) in
            return (`class`, distribution.reduce(1, *) * (probaClass[`class`] ?? 0.0))
        }

        let sum = likelihoods.map { $0.1 }.reduce(0, +)
        let normalized = likelihoods.map { (`class`, likelihood) in
            return (`class`, likelihood / sum)
        }

        return normalized
    }
}
