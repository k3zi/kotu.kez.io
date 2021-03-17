import Foundation

struct SpeechSynthesis: Encodable {
    enum CodingKeys: String, CodingKey {
        case engine = "Engine"
        case languageCode = "LanguageCode"
        case lexiconNames = "LexiconNames"
        case outputFormat = "OutputFormat"
        case sampleRate = "SampleRate"
        case speechMarkTypes = "SpeechMarkTypes"
        case text = "Text"
        case textType = "TextType"
        case voiceId = "VoiceId"
    }
    let engine: String
    let languageCode: String
    let lexiconNames: [String]
    let outputFormat: String
    let sampleRate: String
    let speechMarkTypes: [String]
    let text: String
    let textType: String
    let voiceId: String
}
