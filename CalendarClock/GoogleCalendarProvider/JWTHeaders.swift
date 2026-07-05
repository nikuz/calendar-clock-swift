struct JWTHeaders: Codable {
    // let kid: String
    var alg = "RS256"
    var typ = "JWT"
}