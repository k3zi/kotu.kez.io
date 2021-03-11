//
//  Node.swift
//  MeCab
//
//  Created by Yusuke Ito on 12/25/15.
//  Copyright © 2015 Yusuke Ito. All rights reserved.
//

#if os(Linux)
    import CMeCab
#endif

#if os(macOS)
    import CMeCabOSX
#endif

public protocol TokenNode {
    var isBosEos: Bool { get }
    var surface: String { get }
    var features: [String] { get }
}

extension Node {
    public enum `Type`: Int {
        case normal = 0
        case unknown = 1
        case beginOfSentence = 2
        case endOfSentence = 3
        case endOfNBestEnumeration = 4
    }
}

extension String {

    mutating func remove(upToAndIncluding idx: Index) {
        self = String(self[index(after: idx)...])
    }

    mutating func parseField() -> String {
        assert(!self.isEmpty)
        switch self[startIndex] {
        case "\"":
            removeFirst()
            guard let quoteIdx = firstIndex(of: "\"") else {
                fatalError("expected quote")
            }
            let result = prefix(upTo: quoteIdx)
            remove(upToAndIncluding: quoteIdx)
            if !isEmpty {
                let comma = removeFirst()
                assert(comma == ",")
            }
            return String(result)

        default:
            if let commaIdx = firstIndex(of: ",") {
                let result = prefix(upTo: commaIdx)
                remove(upToAndIncluding: commaIdx)
                return String(result)
            } else {
                let result = self
                removeAll()
                return result
            }
        }
    }
}

func parse(line: String) -> [String] {
    var remainder = line
    var result: [String] = []
    while !remainder.isEmpty {
        result.append(remainder.parseField())
    }
    return result
}

public struct Node: TokenNode, CustomStringConvertible {
    public let isBosEos: Bool
    public let surface: String
    public var features: [String]
    public var alwaysHideFurigana = false
    public let type: Type

    public init(surface: String, features: [String], type: Type) {
        self.isBosEos = type == .beginOfSentence || type == .endOfSentence
        self.surface = surface
        self.features = features
        self.type = type
    }
    
    init(_ node: UnsafePointer<mecab_node_t>) throws {
        let surfaceBuf: [Int8] = {
            var buf:[Int8] = []
            for i in 0..<node.pointee.length {
                buf.append(node.pointee.surface[Int(i)])
            }
            buf.append(0)
            return buf
        }()
        
        
        let featureBuf: [Int8] = {
            var buf: [Int8] = []
            var i = 0
            while i <= max(Int(node.pointee.length)*2, 1000) {
                let val = node.pointee.feature[Int(i)]
                if val == 0 {
                    break
                }
                buf.append(val)
                i += 1
            }
            buf.append(0)
            return buf
        }()
        
        guard let surface = String(validatingUTF8: surfaceBuf),
            let feature = String(validatingUTF8: featureBuf),
            let type = Type(rawValue: Int(node.pointee.stat)) else {
                throw MecabError.nodeParseError
        }
        self.surface = surface as String
        self.features = parse(line: feature)
        if features.count == 0 {
            throw MecabError.nodeParseError
        }
        self.isBosEos = type == .endOfSentence || type == .beginOfSentence
        self.type = type
    }
}

extension Node {
    public var description: String {
        return "\(surface): \(features)"
    }
}
