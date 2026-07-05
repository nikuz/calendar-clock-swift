struct JWTPayload: Codable {
    let iss: String
    let aud: String
    let scope: String
    let exp: Int
    let iat: Int
}