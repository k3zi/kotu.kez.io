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

public struct Node: TokenNode, CustomStringConvertible {
    public let isBosEos: Bool
    public let surface: String
    public let features: [String]
    public let posId: Int
    public let type: Type
    
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
        self.features = feature.split(separator: ",").map(String.init)
        if features.count == 0 {
            throw MecabError.nodeParseError
        }
        self.isBosEos = type == .endOfSentence || type == .beginOfSentence
        self.type = type
        self.posId = Int(node.pointee.posid)
    }
}

extension Node {
    public var description: String {
        return "\(surface): \(posId) \(features)"
    }
}
