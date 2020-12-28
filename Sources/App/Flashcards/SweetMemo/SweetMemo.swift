import Foundation

fileprivate let rangeAF: Int = 20
fileprivate let rangeRepetition: Int = 20

fileprivate let minAF: Double = 1.2
fileprivate let notchAF: Double = 0.3
fileprivate let maxAF = minAF + notchAF * (Double(rangeAF) - 1)
fileprivate let maxAFsCount = 30

fileprivate let maxGrade: Double = 5
fileprivate let thresholdRecall: Double = 3
fileprivate let initialRepValue: Double = 1

fileprivate let forgotten: Double = 1
fileprivate let remembered: Double = 100 + forgotten
fileprivate let maxPointsCount = 500
fileprivate let maxPoints = 5000
fileprivate let gradeOffset: Double = 1

class SweetMemo<Card: Codable>: Codable {

    var requestedFI: Double = 10
    var intervalBase: Double = 3 * 60 * 60
    var forgettingIndexGraph: ForgettingIndexGraph!
    var forgettingCurves: ForgettingCurves!
    lazy var rfm = RFactorMatrix(sm: self)
    lazy var ofm = OptimumFactorMatrix(sm: self)

    var queue: [Item<Card>]

    init() {
        queue = []
        forgettingCurves = ForgettingCurves.load(sm: self)
        forgettingIndexGraph = ForgettingIndexGraph()
    }

    public func addItem(card: Card) {
        let item = Item(sm: self, card: card)
        queue.append(item)
        queue.sort(by: { $0.dueDate < $1.dueDate })
    }

    public func nextItem(isAdvanceable: Bool = false) -> Item<Card>? {
        guard queue.count > 0 else { return nil }
        let first = queue[0]
        return (isAdvanceable || first.dueDate < Date()) ? first : nil
    }

    public func answer(grade: Double, item: inout Item<Card>, now: Date = .init()) {
        update(grade: grade, item: &item, now: now)
    }

    private func update(grade: Double, item: inout Item<Card>, now: Date = .init()) {
        if item.repetition > 0 {
            forgettingCurves.registerPoint(sm: self, grade: grade, item: &item, now: now)
            ofm.update()
            forgettingIndexGraph.update(sm: self, grade: grade, item: item, now: now)
        }
        item.answer(sm: self, grade: grade, now: now)
    }

}

protocol Itemizable {

    associatedtype Card: Codable
    var lapse: Int { get }
    var repetition: Int { get }
    var of: Double { get }

    mutating func afIndex() -> Int
    func uf(sm: SweetMemo<Card>, now: Date) -> Double

}

extension Itemizable {

    func uf(sm: SweetMemo<Card>) -> Double {
        uf(sm: sm, now: .init())
    }

}

extension SweetMemo {

    class Item<Card: Codable>: Itemizable, Codable {

        let card: Card

        var lapse = 0
        var repetition = -1
        var of: Double = 1
        var optimumInterval: Double
        var dueDate = Date()
        var previousDate: Date?
        private var af: Double?
        private var afs = [Double]()

        init(sm: SweetMemo<Card>, card: Card) {
            self.card = card
            self.optimumInterval = sm.intervalBase
        }

        func interval(sm: SweetMemo<Card>, now: Date = .init()) -> TimeInterval {
            guard let previousDate = previousDate else {
                return sm.intervalBase
            }

            return now.timeIntervalSince(previousDate)
        }

        func uf(sm: SweetMemo<Card>, now: Date = .init()) -> Double {
            interval(sm: sm, now: now) / (optimumInterval / of)
        }

        func af(value: Double? = nil) -> Double {
            guard let value = value else {
                // Is af ever nil in usage?
                return af ?? minAF
            }

            let a = round((value - minAF) / notchAF)
            af = max(minAF, min(maxAF, minAF + a * notchAF))
            return af!
        }

        func afIndex() -> Int {
            let afs = (0...rangeAF).map { minAF + Double($0) * notchAF }
            return (0...rangeAF).reduce(0, { a, b in
                abs(af() - afs[a]) < abs(af() - afs[b]) ? a : b
            })
        }

        private func I(sm: SweetMemo<Card>, now: Date = .init()) {
            let of = sm.ofm.of(repetition: repetition, afIndex: repetition == 0 ? lapse : afIndex())
            self.of = max(1, (of - 1) * (interval(sm: sm, now: now) / optimumInterval) + 1)
            optimumInterval = round(optimumInterval * self.of)

            previousDate = now
            dueDate = Date(timeIntervalSinceNow: optimumInterval)
        }

        private func updateAF(sm: SweetMemo<Card>, grade: Double, now: Date = .init()) {
            let estimatedFI = max(1, sm.forgettingIndexGraph.forgettingIndex(grade: grade))
            let correctedUF = uf(sm: sm, now: now) * (sm.requestedFI / estimatedFI)
            let estimatedAF = repetition > 0
                ? sm.ofm.af(repetition: repetition, of: correctedUF)
                : max(minAF, min(maxAF, correctedUF))

            afs.append(estimatedAF)
            afs = afs.suffix(maxAFsCount)
            let x = afs.enumerated().map { i, a in a * (Double(i) + 1) }.reduce(0, +)
            let y = (1..<afs.count).reduce(0, +)
            _ = af(value: x / Double(y))
        }

        func answer(sm: SweetMemo<Card>, grade: Double, now: Date = .init()) {
            if repetition >= 0 {
                updateAF(sm: sm, grade: grade, now: now)
            }

            if grade >= thresholdRecall {
                if repetition < (rangeRepetition - 1) {
                    repetition += 1
                }
                I(sm: sm, now: now)
            } else {
                if lapse < (rangeAF - 1) {
                    lapse += 1
                }
                optimumInterval = sm.intervalBase
                previousDate = nil
                dueDate = now
                repetition = -1
            }
        }

    }

}

extension SweetMemo {

    struct Graph {

        let y: (Double) -> Double
        let x: (Double) -> Double
        let a: Double
        let b: Double
        let mse: Double

    }

    struct Model {

        let y: (Double) -> Double
        let x: (Double) -> Double
        let a: Double
        let b: Double

    }

    struct LRResult {

        let y: (Double) -> Double
        let x: (Double) -> Double
        let b: Double

    }

    static func mse(y: (Double) -> Double, points: [Point]) -> Double {
        let sum = points
            .map { y($0.x) - $0.y }
            .map { $0 * $0 }
            .reduce(0, +)
        return sum / Double(points.count)
    }

    static func exponentialRegression(points: [Point]) -> Graph {
        let n = Double(points.count)
        let X = points.map { $0.x }
        let Y = points.map { $0.y }
        let logY = Y.map { log($0) }
        let sqX = X.map { $0 * $0 }

        let sumLogY = logY.reduce(0, +)
        let sumSqX = sqX.reduce(0, +)
        let sumX = X.reduce(0, +)
        let sumXLogY = zip(X, logY).map(*).reduce(0, +)
        let sqSumX = sumX * sumX

        let a = (sumLogY * sumSqX - sumX * sumXLogY) / (n * sumSqX - sqSumX)
        let b = (n * sumXLogY - sumX * sumLogY) / (n * sumSqX - sqSumX)
        let _y: (Double) -> Double = { exp(a) * exp(b * $0)  }
        return Graph(
            y: _y,
            x: { (-a + log($0)) / b },
            a: exp(a),
            b: b,
            mse: mse(y: _y, points: points)
        )
    }

    static func linearRegression(points: [Point]) -> Model {
        let n = Double(points.count)
        let X = points.map { $0.x }
        let Y = points.map { $0.y }
        let sqX = X.map { $0 * $0 }

        let sumY = Y.reduce(0, +)
        let sumSqX = sqX.reduce(0, +)
        let sumX = X.reduce(0, +)
        let sumXY = zip(X, Y).map(*).reduce(0, +)
        let sqSumX = sumX * sumX

        let a = (sumY * sumSqX - sumX * sumXY) / (n * sumSqX - sqSumX)
        let b = (n * sumXY - sumX * sumY) / (n * sumSqX - sqSumX)
        let _y: (Double) -> Double = { a + b * $0 }
        return Model(
            y: _y,
            x: { ($0 - a) / b },
            a: a,
            b: b
        )
    }

    static func fixedPointPowerLawRegression(points: [Point], fixedPoint: Point) -> Model {
        let p = fixedPoint.x
        let q = fixedPoint.y
        let logQ = log(q)
        let X = points.map { log($0.x / p) }
        let Y = points.map { log($0.y) - logQ }
        let b = linearRegressionThroughOrigin(points: zip(X, Y).map { Point(x: $0, y: $1) }).b
        return powerLawModel(a: q / pow(p, b), b: b)
    }

    static func linearRegressionThroughOrigin(points: [Point]) -> LRResult {
        let X = points.map { $0.x }
        let Y = points.map { $0.y }

        let sumXY = zip(X, Y).map(*).reduce(0, +)
        let sumSqX = zip(X, X).map(*).reduce(0, +)
        let b = sumXY / sumSqX
        return .init(
            y: { b * $0 },
            x: { $0 / b },
            b: b
        )
    }

    static func powerLawModel(a: Double, b: Double) -> Model {
        return .init(
            y: { a * pow($0, b) },
            x: { pow($0 / a, 1 / b) },
            a: a,
            b: b
        )
    }

}

extension SweetMemo {

    struct ForgettingCurves: Codable {

        var curves: [[ForgettingCurve]]

        static func load(sm: SweetMemo, points: [[Point]]? = nil) -> ForgettingCurves {
            let curves = (0...rangeRepetition).map { (r: Int) -> [ForgettingCurve] in
                (0...rangeAF).map { (a: Int) -> ForgettingCurve in
                    let dr = Double(r)
                    let da = Double(a)
                    let partialPoints: [Point]
                    if let points = points {
                        partialPoints = [points[r][a]]
                    } else {
                        let p: [Point]
                        if r > 0 {
                            p = (0..<20).map { i -> Point in
                                Point(
                                    x: minAF + notchAF * Double(i),
                                    y: min(
                                        remembered,
                                        exp(
                                            (-(dr + 1) / 200) * (Double(i) - da * (2 / (dr + 1).squareRoot()))
                                        ) * (remembered - sm.requestedFI)
                                    )
                                )
                            }
                        } else {
                            p = (0..<20).map { i -> Point in
                                Point(
                                    x: minAF + notchAF * Double(i),
                                    y: min(
                                        remembered,
                                        exp(
                                            (-1 / (10 + 1 * (da + 1))) * (Double(i) - pow(da, 0.6))
                                        ) * (remembered - sm.requestedFI)
                                    )
                                )
                            }
                        }
                        partialPoints = [Point(x: 0, y: remembered)] + p
                    }
                    return ForgettingCurve(points: partialPoints)
                }
            }

            return .init(curves: curves)
        }

        mutating func registerPoint<Item: Itemizable>(sm: SweetMemo<Item.Card>, grade: Double, item: inout Item, now: Date = .init()) {
            let afIndex = item.repetition > 0 ? item.afIndex() : item.lapse
            curves[item.repetition][afIndex].registerPoint(grade: grade, uf: item.uf(sm: sm, now: now))
        }

    }

    struct ForgettingCurve: Codable {

        var points: [Point]
        lazy var graph: Graph? = nil

        mutating func registerPoint(grade: Double, uf: Double) {
            let isRemembered = grade >= thresholdRecall
            points.append(Point(x: uf, y: isRemembered ? remembered : forgotten))
            points = points.suffix(maxPointsCount)
            graph = nil
        }

        mutating func retention(uf: Double) -> Double {
            let graph = self.graph ?? SweetMemo.exponentialRegression(points: points)
            self.graph = graph
            return max(forgotten, min(graph.y(uf), remembered)) - forgotten
        }

        mutating func uf(retention: Double) -> Double {
            let graph = self.graph ?? SweetMemo.exponentialRegression(points: points)
            self.graph = graph
            return max(0, graph.x(retention + forgotten))
        }

    }

}

extension SweetMemo {

    struct RFactorMatrix {

        let sm: SweetMemo

        func rFactor(repetition: Int, afIndex: Int) -> Double {
            sm.forgettingCurves.curves[repetition][afIndex].uf(retention: 100 - sm.requestedFI)
        }

    }

}

extension SweetMemo {

    struct PointModel {
        let x: (Double) -> Double
        let y: (Double) -> Double
    }

    struct OptimumFactorMatrix {

        static func afFromIndex(a: Int) -> Double {
            Double(a) * notchAF + minAF
        }

        static func repFromIndex(r: Double) -> Double {
            r + initialRepValue
        }

        let sm: SweetMemo
        private var ofm: ((Int) -> PointModel)? = nil
        private var ofm0: ((Int) -> Double)? = nil

        init(sm: SweetMemo) {
            self.sm = sm
            self.update()
        }

        func rFactor(repetition: Int, afIndex: Int) -> Double {
            sm.forgettingCurves.curves[repetition][afIndex].uf(retention: 100 - sm.requestedFI)
        }

        mutating func update() {
            var dfs: [Double] = (0...rangeAF).map { a in
                SweetMemo.fixedPointPowerLawRegression(points: (1...rangeRepetition).map { r in
                    Point(x: Self.repFromIndex(r: Double(r)), y: sm.rfm.rFactor(repetition: r, afIndex: a))
                }, fixedPoint: Point(x: Self.repFromIndex(r: 1), y: Self.afFromIndex(a: a))).b
            }
            dfs = (0...rangeAF).map { Self.afFromIndex(a: $0) / pow(2, dfs[$0]) }
            let decay = SweetMemo.linearRegression(points: (0...rangeAF).map { Point(x: Double($0), y: dfs[$0]) })
            self.ofm = { a in
                let af = Self.afFromIndex(a: a)
                let b = log(af / decay.y(Double(a))) / log(Self.repFromIndex(r: 1))
                let model = SweetMemo.powerLawModel(a: af / pow(Self.repFromIndex(r: 1), b), b: b)
                return .init(
                    x: { model.x($0) - initialRepValue },
                    y: { model.y(Self.repFromIndex(r: $0)) }
                )
            }

            let ofm0 = SweetMemo.exponentialRegression(points: (0...rangeAF).map { Point(x: Double($0), y: sm.rfm.rFactor(repetition: 0, afIndex: $0)) })
            self.ofm0 = { ofm0.y(Double($0)) }
        }

        func of(repetition: Int, afIndex: Int) -> Double {
            repetition == 0
                ? ofm0!(afIndex)
                : ofm!(afIndex).y(Double(repetition))
        }

        func af(repetition: Int, of of_: Double) -> Double {
            Double(Self.afFromIndex(a: (0...rangeAF).reduce(0, { a, b -> Int in
                abs(of(repetition: repetition, afIndex: a) - of_) < abs(of(repetition: repetition, afIndex: b) - of_)
                    ? a
                    : b
            })))
        }

    }

}

extension SweetMemo {

    struct Point: Codable {
        /// Forgetting index
        let x: Double
        /// Grade
        let y: Double
    }

}

extension SweetMemo {
    

    struct ForgettingIndexGraph: Codable {

        var points: [Point]
        lazy var graph: Graph? = nil

        init(points: [Point]? = nil) {
            if let points = points {
                self.points = points
            } else {
                self.points = []
                registerPoint(fi: .zero, g: maxGrade)
                registerPoint(fi: 100, g: .zero)
            }
        }

        mutating func registerPoint(fi: Double, g: Double) {
            points.append(Point(x: fi, y: g))
            points = points.suffix(maxPoints)
        }

        mutating func update<Item: Itemizable>(sm: SweetMemo<Item.Card>, grade: Double, item: Item, now: Date = .init()) {
            let expectedFI = (item.uf(sm: sm, now: now) / item.of) * sm.requestedFI
            registerPoint(fi: expectedFI, g: grade)
            graph = nil
        }

        mutating func forgettingIndex(grade: Double) -> Double {
            graph = graph ?? SweetMemo.exponentialRegression(points: points)
            return max(0, min(100, graph?.x(grade + gradeOffset) ?? 0))
        }

        mutating func grade(forgettingIndex fi: Double) -> Double {
            graph = graph ?? SweetMemo.exponentialRegression(points: points)
            return (graph?.y(fi) ?? 0) - gradeOffset
        }

    }

}

extension ClosedRange where Bound: Strideable, Bound.Stride: SignedInteger {

    // Assumes that the slice will not be empty. ClosedRange must have at least
    // one element.
    init(_ slice: Slice<ClosedRange<Bound>>) {
        self.init(uncheckedBounds: (slice.first!, slice.last!))
    }

}
