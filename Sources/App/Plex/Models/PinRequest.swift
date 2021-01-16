import Foundation
import Vapor

public struct PinRequest: Content {

    public let id: Int
    public let code: String
    public let expiresAt: Date
    public let userId: Int?
    public let clientIdentifier: String
    public let trusted: Bool
    public let authToken: String?

}

public struct SignInResponse: Content {
    let inviteCode: String
    let linked: PinRequest?
}
