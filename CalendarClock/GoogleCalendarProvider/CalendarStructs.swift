import Foundation

struct JWTHeaders: Codable {
    // let kid: String
    var alg = "RS256"
    var typ = "JWT"
}

struct JWTPayload: Codable {
    let iss: String
    let aud: String
    let scope: String
    let exp: Int
    let iat: Int
}

struct CalendarWatchPayload: Codable {
    let id: String
    let address: String
    var type = "web_hook"
    var token: String

    init(id: String, address: String, user: String, password: String) {
        self.id = id
        self.address = address

        let credentials = "\(user):\(password)"
        let base64Credentials = credentials.data(using: .utf8)?.base64EncodedString() ?? ""
        self.token = "Basic \(base64Credentials)"
    }
}

struct CalendarWatchChannel: Codable {
  let id: String
  let kind: String
  let resourceId: String
  let resourceUri: String
  let expiration: String
}

struct CalendarStopWatchingPayload: Codable {
    let id: String
    let resourceId: String
}