import Foundation
import IkigaJSON
import Vapor

extension IkigaJSONEncoder: ContentEncoder {
    public func encode<E: Encodable>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws {
        headers.contentType = .json
        try self.encodeAndWrite(encodable, into: &body)
    }
}

extension IkigaJSONDecoder: ContentDecoder {
    public func decode<D: Decodable>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D {
        guard headers.contentType == .json || headers.contentType == .jsonAPI else {
            throw Abort(.unsupportedMediaType)
        }

        return try self.decode(D.self, from: body)
    }
}
