import Foundation
import Vapor

extension ClientResponse {
    var data: Data {
        Data(buffer: body ?? .init())
    }
}

public enum PlexError: Error {
    case dataParsingError
    case invalidRootKeyPath
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

public class Plex {

    static var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    enum Settings: String {
        case userId
        case authToken
    }

    enum SignInStatus {
        case noCredentials
        case authenticating(code: String)
        case signedIn
    }

    enum RequestBuilder {
        fileprivate static var tvBase = "https://plex.tv"
        case librarySectionTracks(connectionURI: String, sectionKey: String)
        case syncItems(clientIdentifier: String)
        case syncItemTracks(connectionURI: String, syncItemId: Int)
        case sections(connectionURI: String)

        private var urlString: String {
            switch self {
            case .librarySectionTracks(let connectionURI, let sectionKey):
                return "\(connectionURI)/library/sections/\(sectionKey)/all?type=10&includeRelated=1&includeCollections=1"

            case .sections(let connectionURI):
                return "\(connectionURI)/library/sections"

            case .syncItems(let clientIdentifier):
                let id = clientIdentifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
                return "\(type(of: self).tvBase)/devices/\(id)/sync_items"

            case .syncItemTracks(let connectionURI, let syncItemId):
                return "\(connectionURI)/sync/items\(syncItemId)"
            }
        }

        var url: URL {
            return URL(string: urlString)!
        }
    }

    struct Path {
        static let _plexTV = "https://plex.tv"
        static let linkAccount = "\(_plexTV)/link"

        enum Pins {
            static let _pins = "\(_plexTV)/pins"
            static let request = "\(_pins).json"
            static func check(pin pinId: Int) -> String {
                return "\(_pins)/\(pinId).json"
            }
        }

        enum PMS {
            static let _pms = "\(_plexTV)/pms"
            static let servers = "\(_pms)/servers"
        }

        enum API {
            static let _api = "\(_plexTV)/api/v2"
            static let resources = "\(_api)/resources"
        }
    }

    lazy var clientIdentifier: String = {
        // TODO: Don't save the identifier to the user defaults.
        if let storedIdentifier = UserDefaults.standard.string(forKey: "clientIdentifier") {
            return storedIdentifier
        }

        let identifier = Host.current().address ?? "NoHostAddress"
        UserDefaults.standard.set(identifier, forKey: "clientIdentifier")
        return identifier
    }()

    lazy var requestHeaders: [String: String] = {
        let deviceName = Host.current().name ?? "NoHostName"
        return [
            "Accept": "application/json",
            "X-Plex-Platform": "Web",
            "X-Plex-Platform-Version": "1.0.0",
            "X-Plex-Provides": "player",
            "X-Plex-Client-Identifier": clientIdentifier,
            "X-Plex-Product": Bundle.main.bundleIdentifier ?? "NoBundleIdentifier",
            "X-Plex-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "NoBundleShortVersionString",
            "X-Plex-Device": deviceName,
            "X-Plex-Device-Name": [Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "(\(deviceName)"]
                .compactMap { $0 }.joined(separator: " "),
            "X-Plex-Sync-Version": "2"
        ]
    }()

    lazy var requestHeadersQuery = requestHeaders.map { pair -> String in

        let key = pair.key
        let value = pair.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return key + "=" + value
    }.joined(separator: "&")

    // MARK: - API -

    // MARK: Sign In

    public func signIn(client: Client) -> EventLoopFuture<PinRequest> {
        return post(client: client, Path.Pins.request)
            .flatMapThrowing { (response: ClientResponse) in
                try response.content.decode(PinRequestResponse.self, using: Self.decoder)
            }
            .map { $0.pin }
    }

    public func checkPin(client: Client, id: Int) -> EventLoopFuture<SignInResponse> {
        return get(client: client, Path.Pins.check(pin: id)).flatMapThrowing { (response: ClientResponse) in
            try response.content.decode(PinRequestResponse.self, using: Self.decoder)
        }
        .map { $0.pin }
        .map {
            if $0.authToken != nil {
                return SignInResponse(inviteCode: $0.code, linked: $0)
            } else {
                return SignInResponse(inviteCode: $0.code, linked: nil)
            }
        }
    }

    // MARK: Info
    public func resources(client: Client, token: String? = nil) -> EventLoopFuture<[Resource]> {
        get(client: client, "\(Path.API.resources)?includeHttps=1&includeRelay=1", token: token)
            .flatMapThrowing { response in
                try response.content.decode([Resource].self)
            }
    }

    public func providers(client: Client, resource: Resource) -> EventLoopFuture<[Section]> {
        guard let connection = resource.connections.first(where: { !$0.local }) else {
            return client.eventLoop.future(error: Abort(.badRequest))
        }
        return get(client: client, connection.uri.appendingPathComponent("media/providers").absoluteString, token: resource.accessToken)
            .flatMapThrowing { (response: ClientResponse) in
                 try response.content.decode(ProviderResponse.self)
            }
            .map { (response: ProviderResponse) in
                let features: [ProviderResponse.MediaContainer.MediaProvider.Feature] = response.MediaContainer.MediaProvider
                    .flatMap { $0.Feature }
                    .filter { $0.key == "/library/sections" }
                return features
                    .flatMap { $0.Directory ?? [] }
                    .filter { $0.id != nil }
                    .map { Section(title: $0.title, type: $0.type ?? "", path: $0.key ?? "") }
            }
    }

    public func all(client: Client, resource: Resource, path: String) -> EventLoopFuture<[Metadata]> {
        guard let connection = resource.connections.first(where: { !$0.local }) else {
            return client.eventLoop.future(error: Abort(.badRequest))
        }
        return get(client: client, connection.uri.appendingPathComponent(path).absoluteString + "?X-Plex-Container-Start=0&X-Plex-Container-Size=1000&includeCollections=1&includeExternalMedia=1&includeAdvanced=1&includeMeta=1", token: resource.accessToken)
            .flatMapThrowing { (response: ClientResponse) in
                 try response.content.decode(AllResponse.self)
            }
            .map { (response: AllResponse) in
                return response.MediaContainer.Metadata
            }
    }

}

struct PlexURLRequest {
    let url: URL
    var headers: [String: String] = [:]
}

extension Plex {

    private func makeURLRequest(urlString: String, token: String? = nil) -> PlexURLRequest {
        var request = PlexURLRequest(url: URL(string: urlString)!, headers: requestHeaders)
        request.headers["X-Plex-Token"] = token
        request.headers["Content-Type"] = "application/json"
        return request
    }

    private func get(client: Client, _ url: String, headers additionalHeaders: HTTPHeaders = .init(), token: String? = nil, timeoutInterval: TimeInterval? = nil) -> EventLoopFuture<ClientResponse> {
        let request = makeURLRequest(urlString: url, token: token)
        let url = request.url
        var headers = request.headers.map {
            ($0.key, $0.value)
        }
        headers += additionalHeaders.map { ($0.name, $0.value) }

        return client.get(.init(string: url.absoluteString), headers: HTTPHeaders(headers))
    }

    private func download(client: Client, _ url: String, to saveLocation: URL, token: String? = nil, timeoutInterval: TimeInterval? = nil) -> EventLoopFuture<ClientResponse> {
        let request = makeURLRequest(urlString: url, token: token)
        let url = request.url
        let headers = request.headers.map {
            ($0.key, $0.value)
        }
        return client.get(.init(string: url.absoluteString), headers: HTTPHeaders(headers))
    }

    private func post(client: Client, _ url: String, token: String? = nil, timeoutInterval: TimeInterval? = nil) -> EventLoopFuture<ClientResponse> {
        let request = makeURLRequest(urlString: url, token: token)
        let url = request.url
        let headers = request.headers.map {
            ($0.key, $0.value)
        }
        return client.post(.init(string: url.absoluteString), headers: HTTPHeaders(headers))
    }

    private func put(client: Client, _ url: String, token: String? = nil, timeoutInterval: TimeInterval? = nil) -> EventLoopFuture<ClientResponse> {
        let request = makeURLRequest(urlString: url, token: token)
        let url = request.url
        let headers = request.headers.map {
            ($0.key, $0.value)
        }
        return client.put(.init(string: url.absoluteString), headers: HTTPHeaders(headers))
    }

}
