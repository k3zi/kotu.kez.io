import Vapor

extension Settings {

    enum Keybind: Content {

        enum CodingKeys: String, CodingKey {
            case keys
            case ctrlKey
            case shiftKey
            case altKey
            case metaKey
        }

        case with(keys: [String], ctrlKey: Bool, shiftKey: Bool, altKey: Bool, metaKey: Bool)
        case disabled

        init(from decoder: Decoder) throws {
            let singleValueContainer = try? decoder.singleValueContainer()
            if let stringValue = try? singleValueContainer?.decode(String.self), stringValue == "disabled" {
                self = .disabled
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let keys = try container.decode([String].self, forKey: .keys)
                let ctrlKey = try container.decode(Bool.self, forKey: .ctrlKey)
                let shiftKey = try container.decode(Bool.self, forKey: .shiftKey)
                let altKey = try container.decode(Bool.self, forKey: .altKey)
                let metaKey = try container.decode(Bool.self, forKey: .metaKey)
                self = .with(keys: keys, ctrlKey: ctrlKey, shiftKey: shiftKey, altKey: altKey, metaKey: metaKey)
            }
        }

        func encode(to encoder: Encoder) throws {
            switch self {
            case .with(keys: let keys, ctrlKey: let ctrlKey, shiftKey: let shiftKey, altKey: let altKey, metaKey: let metaKey):
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(keys, forKey: .keys)
                try container.encode(ctrlKey, forKey: .ctrlKey)
                try container.encode(shiftKey, forKey: .shiftKey)
                try container.encode(altKey, forKey: .altKey)
                try container.encode(metaKey, forKey: .metaKey)
            case .disabled:
                var container = encoder.singleValueContainer()
                try container.encode("disabled")
            }
        }
    }

}
