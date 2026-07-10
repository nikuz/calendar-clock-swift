import Foundation

struct AccessToken : Codable {
    let accessToken: String
    let tokenType: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken
        case tokenType
        case expiresAt
        case expiresIn  // needed for decoding, but not a stored property
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        
        if let storedExpiresAt = try container.decodeIfPresent(Int.self, forKey: .expiresAt) {
            expiresAt = storedExpiresAt
        } else {
            let expiresIn = try container.decode(Int.self, forKey: .expiresIn)
            expiresAt = Int(Date().timeIntervalSince1970) + expiresIn
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encode(expiresAt, forKey: .expiresAt)
    }
}