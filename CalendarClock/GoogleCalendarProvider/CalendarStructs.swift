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
    var type = "web_hook"
    var address = "https://humorous-repent-joyfully.ngrok-free.dev"
}

struct CalendarWatchResponse: Decodable {
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