import Foundation

public class DataTokenizer {

    enum Error: Swift.Error {
        case notEqual(String)
    }

    let data: Data
    var currentIndex: Data.Index
    var currentOffset: Int

    public init(data: Data) {
        self.data = data
        self.currentIndex = data.startIndex
        self.currentOffset = 0
    }

    @discardableResult
    func consume() -> UInt8 {
        let result = data[currentIndex]
        currentIndex = data.index(after: currentIndex)
        currentOffset += 1
        return result
    }

    func consume(expect value: UInt8) throws {
        if consume() != value {
            throw Error.notEqual("consume expected \(value)")
        }
    }

    @discardableResult
    func consume(times: Int) -> [UInt8] {
        var result = [UInt8]()
        for _ in 0..<times {
            result.append(consume())
        }
        return result
    }

    @discardableResult
    func consume(maxTimes times: Int) -> [UInt8] {
        var result = [UInt8]()
        for _ in 0..<times {
            if reachedEnd {
                break
            }
            result.append(consume())
        }
        return result
    }

    @discardableResult
    func consumeUntil(nextByteGroupOf group: Int, and condition: (UInt8) -> Bool = { _ in true }) -> [UInt8] {
        var result = [UInt8]()
        while !reachedEnd && (!currentOffset.isMultiple(of: group) || !condition(next)) {
            result.append(consume())
        }
        return result
    }

    func dataConsuming(times: Int) -> Data {
        var result = [UInt8]()
        for _ in 0..<times {
            result.append(consume())
        }
        return Data(result)
    }

    @discardableResult
    func consumeInt32() -> UInt32 {
        return consume(times: 4).withUnsafeBufferPointer {
                 ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
        }.pointee
    }

    var nextInt32: UInt32 {
        return Array(data[currentIndex..<(currentIndex + 4)]).withUnsafeBufferPointer {
                 ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
        }.pointee
    }

    func consumeInt32(expect value: UInt32) throws {
        if consumeInt32() != value {
            throw Error.notEqual("consumeInt32 expected \(value)")
        }
    }

    var next: UInt8 {
        data[currentIndex]
    }

    var reachedEnd: Bool {
        data.endIndex == currentIndex
    }

}
