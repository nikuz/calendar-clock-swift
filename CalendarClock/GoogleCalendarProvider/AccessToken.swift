import Foundation

struct AccessToken : Decodable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String

    var expiresAt: Int {
        Int(Date().timeIntervalSince1970) + expiresIn
    }
}