//import Foundation
//
//class TagReplacer: NSObject, XMLParserDelegate {
//
//    @Published var didFinish = false
//    @Published var result = ""
//
//    init(text: String) {
//        super.init()
//        let parser = XMLParser(data: text.data(using: .utf8)!)
//        parser.delegate = self
//        parser.parse()
//    }
//
//    optional func parserDidStartDocument(_ parser: XMLParser) {
//
//    }
//
//    optional func parserDidEndDocument(_ parser: XMLParser) {
//
//    }
//
//
//    optional func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?) {
//
//    }
//
//
//    optional func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?)
//
//
//    optional func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String, type: String?, defaultValue: String?)
//
//
//    optional func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String)
//
//
//    optional func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?)
//
//
//    optional func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?)
//
//
//    optional func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:])
//
//
//    optional func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
//
//
//    optional func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String)
//
//
//    optional func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String)
//
//
//    optional func parser(_ parser: XMLParser, foundCharacters string: String)
//
//
//    optional func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
//
//    }
//
//
//    optional func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
//
//    }
//
//
//    optional func parser(_ parser: XMLParser, foundComment comment: String) {
//
//    }
//
//
//    optional func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
//
//    }
//
//}
