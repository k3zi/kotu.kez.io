import Foundation
import Vapor

public struct Resource: Content {

    public struct Connection: Content {
        let local: Bool
        let uri: URL
    }

    let name: String
    let provides: String
    let accessToken: String?
    let clientIdentifier: String
    let connections: [Connection]
}

public struct Section: Content {

    let title: String
    let type: String
    let path: String

}

struct ProviderResponse: Content {

    struct MediaContainer: Content {

        struct MediaProvider: Content {

            struct Feature: Content {

                struct Directory: Content {
                    let id: String?
                    let key: String?
                    let title: String
                    let type: String?
                    let uuid: UUID?
                }

                let Directory: [Directory]?
                let key: String?
                let type: String
            }

            let Feature: [Feature]
        }

        let MediaProvider: [MediaProvider]
    }

    let MediaContainer: MediaContainer
}

struct AllResponse: Content {

    struct MediaContainer: Content {
        let Metadata: [Metadata]
    }

    let MediaContainer: MediaContainer
}

public struct Metadata: Content {
    struct Media: Content {
        struct Part: Content {
            let key: String
        }
        let id: Int
        let Part: [Part]
    }
    let title: String
    let ratingKey: String
    let duration: Int?
    let key: String
    let art: String?
    let year: Int?
    let type: String
    let index: Int?
    let viewCount: Int?

    let Media: [Media]?
}
