import Vapor

struct RegisterRequestObject: Content {

    let username: String
    let password: String

}

extension RegisterRequestObject: Validatable {

    static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: !.empty)
        validations.add("username", as: String.self, is: .count(4...) && .alphanumeric)

        validations.add("password", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(6...))
    }

}
